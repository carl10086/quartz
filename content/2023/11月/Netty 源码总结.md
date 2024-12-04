

## 1-Intro

> 我们使用 `Netty` `Example` 中的 `Echo` 代码做为调研对象

### 1-1 Server Start


> EventLoop 对应一个线程资源


- 每个 `EventLoop` 有自己独立的 `Selector`, 如果是 `Linux`, 会是一个独立的 `Epoll`实例， 也就是有自己独立的 **双向链表** 和 **红黑树** , 这样可以把资源共享的粒度最小化，真正实现 **彻底的无锁**
- `Netty` 一般的玩法是 `Reactor`, `Boss` + `Worker`
	- 一个 `Boss` 有 1个 `EventLoop` 专门关注于 客户端发过来的连接请求
	- `Worker` 默认有的个数是 `Math.max(1, SystemPropertyUtil.getInt(   "io.netty.eventLoopThreads", NettyRuntime.availableProcessors() * 2))` 个 
- `Netty` 的设计称为 **封闭模型**, 每个连接 `Channel` 都会在 `workerEventGroupLoop` 中注册一个 **唯一的线程**， 分配的一个新的 `ChannelPipeline` 实例, 全程是 **无锁的**, 不仅代码简单，而且性能很高 ;
- 因此 **一个 worker** 的 `EventLoop` 经常要同时处理各种任务，这里也是 并发性能优化的关键， `Netty` 选择 [JcTools](https://github.com/JCTools/JCTools) 库作为高并发的关键, 核心是这个库解决了 伪共享的问题 ;

> Server 大致流程


1. 创建 `EventLoopGroup` ;
2. `doBind` 方法：会触发对应 `Epoll` 实例的创建
	- `initAndRegister` : 是核心方法.
		- 创建 `ServerSocketChannel` 并初始化, 他一般只有一个 `ServerBootstrapAcceptor` `Handler` 用来 接收新的 客户端  `Socket` ;
		- `ServerSocketChannel` 注册 `boss EventGroup`, 异步的创建 `Epoll` 实例
3. 成功的回调也就是 `Epoll` 创建后回调，`epoll_ctl(EPOLL_CTL_MOD)` , 注册  `EPOLLIN` 事件到兴趣列表, 然后绑定到**指定端口**
	- 绑定端口的源码在 `io.netty.channel.AbstractChannel.AbstractUnsafe#bind`




细节的源码追踪过程写在 [Netty-启动服务](https://rocky-rover-393.notion.site/netty_-2f0b07e4644e41c2a58e669eb8149a13?pvs=4)




### 1-2 Accept Client Connection


> `Selector`  如何唤醒一个线程.

官方文档的不准确翻译 .

- Causes the first selection operation that has not yet returned to return immediately. 解除阻塞在Selector.select()/select(long)上的线程，立即返回
    - 如果在调用select()或select(long)方法的过程中，当前有另一个线程被阻塞，那么该调用将立即返回。
    - 当前没有选择操作正在进行，那么这些方法中的一个方法的下一次调用将立即返回，除非在此期间调用了selectNow()方法。
    - 在任何情况下，该调用返回的值可能是非零。随后对select()或select(long)方法的调用将像往常一样阻塞，除非在此期间再次调用该方法。 在两个连续的选择操作之间调用本方法一次以上与只调用一次的效果相同。

Linux 上的实现原理是 利用 pipe 系统调用实现了一个管道. wakeup 会在管道中写入一个 Byte , 这样就产生了事件、 立即返回. 从实现上来看， **是有不可忽视的性能开销** ;


> 之前说过处理新连接的代码在 `ServerBootstrapAcceptor`


1. 处理代码 `ServerBootstrapAcceptor`  逻辑的线程是 `boss` 的线程
2. 收到 `msg`, 是触发了 `Epoll` 的读事件, `boss` 线程这里会创建 `SocketChannel` 的实现来封装这个 客户端连接
3. 然后 这个时候需要把 这个客户端的 `SocketChannel` 使用相同的设计注册到一个 `WorkerEventLoop` 的资源, 这里 **不一定马上唤醒线程处理，因为可能都忙着，只是先注册一下, 有资源的时候会自动的处理的**
4. 注册触发成功的回调，把读事件的 `SelectKey` 加入兴趣列表, 等事件可读自然会触发对应的 线程去处理


同上，[源码细节](https://rocky-rover-393.notion.site/netty_-b0f8a3e11a9e4af4bfde57cae9f979f1?pvs=4)


### 1-3 Read Message

> General About Read Message

1. 读是一个 非阻塞的操作, 尽量多读一些, 尤其是因为 `Netty` 的边缘触发, `ET` 的玩法 ;
2. `TCP` 会有粘包拆包的问题，这里不做解释 ;
3. 比较大的数据包，一次读取读不完, `Netty` 会读 16次 ;
4. 关于 `ByteBuf` 分配直接内存和堆内存，只要和底层打交道, 一定要走一次直接内存，所以应用层面建议分配 堆内存，网络层面建议直接内存


由于代码写的不错，这里贴一下.

```java
				@Override
        public final void read() {
            // 1. 内存分配器 ,获取分配器、默认是 PooledByteBufAllocator(directByDefault:true)
            final ByteBufAllocator allocator = config.getAllocator();
							// 2. 这个 B 是 AdaptiveRecvByteBufAllocator: 看类注释就把算法说的很清楚
								// 2.1 一次不够就增加: 如果上一次的读操作完全填满了分配的缓冲区，它将逐渐增加预期的可读字节数
								// 2.2 二次不够才减少: 如果读操作不能连续两次填满所分配的缓冲区的一定数量，它将逐渐减少可读字节的预期数量。
								// 2.3 否则，它将继续返回相同的预测值。
            final RecvByteBufAllocator.Handle allocHandle = recvBufAllocHandle(); 
							// 3. 这里重置信息: maxMessagePerRead = 16. 就是连读 16次; totalMessages = totalBytesRead = 0; 
            allocHandle.reset(config);

            ByteBuf byteBuf = null;
            boolean close = false;
            try {
                do {
                    // 4.会调用 guess 方法预测下一次分配的字节数. 默认是 1024 个字节， 只是分配这次读的 byteBuf
                    byteBuf = allocHandle.allocate(allocator);
											// 5. 这里会真正的调用 channel readBytes -> byteBuf, 然后记录一下
                    allocHandle.lastBytesRead(doReadBytes(byteBuf));
                    if (allocHandle.lastBytesRead() <= 0) { // 6. 不确定、应该是 没有读到的意思吧
                        // nothing was read. release the buffer.
                        byteBuf.release();
                        byteBuf = null;
                        close = allocHandle.lastBytesRead() < 0;
                        if (close) {
                            // There is nothing left to read as we received an EOF.
                            readPending = false;
                        }
                        break;
                    }
                    // 7. 就是读到了数据、 连读 16次机会 - 1
                    allocHandle.incMessagesRead(1);
                    readPending = false;
                    // 8. 读到了就马上、 触发业务逻辑  fireChannelRead. 也就是说是一个个 ByteBuf 传递的 . 感觉不是特别科学
                    pipeline.fireChannelRead(byteBuf);
											// 9. 业务方都处理了、当然可以 不要了这个 byteBuf, 所以需要业务方保证用完、释放掉啊 
                    byteBuf = null;
                } while (allocHandle.continueReading()); // 10. 判断要不要继续读、读完了啊，次数到了都下去

                allocHandle.readComplete();

                // 4. 触发 fireChannelReadComplete
                pipeline.fireChannelReadComplete();

                if (close) {
                    closeOnRead(pipeline);
                }
            } catch (Throwable t) {
                handleReadException(pipeline, byteBuf, t, close, allocHandle);
            } finally {
                // See https://github.com/netty/netty/issues/2254
                if (!readPending && !config.isAutoRead()) {
                    removeReadOp();
                }
            }
        }


        @Override
        public boolean continueReading(UncheckedBooleanSupplier maybeMoreDataSupplier) {
            return config.isAutoRead() &&
                   (!respectMaybeMoreData || maybeMoreDataSupplier.get()) &&
                   totalMessages < maxMessagePerRead &&
                   totalBytesRead > 0;
        }
```


- `AdaptiveRecvByteBufAllocator` 根据上一次的读取大小 自动增加和减少需要 分配的内存 ;
- 比较好的实现了 `ET`, `continueReading` ;




### 1-4 Biz


- 实现自己的业务也就是 实现一个 `channelRead` 的 `handler` 即可.
- 不建议在 `worker` `thread` 中直接处理业务. 例如可以这样. `pipeline.addLast(new UnorderedThreadPoolEventExecutor(10), serverHandler)` ;




### 1-5 Write Message



```java
		@Override
    protected void doWrite(ChannelOutboundBuffer in) throws Exception { // outboundBuffer 中就是要写的数据了 . 
        SocketChannel ch = javaChannel();
        // 1. 默认获取到是 16, 下面是 -- 所以最多 16次, 原因跟之前的 read 一样
        int writeSpinCount = config().getWriteSpinCount();
        do {
						if (in.isEmpty()) {
                // All written so clear OP_WRITE
                clearOpWrite(); // 这里也非常关键、根本不会出发 inComplete 方法、没有 OP_WRITE、有的话去清理掉
                // Directly return here so incompleteWrite(...) is not called.
                return;
            }

            //2.  需要需要保证 pending write 只能由 ByteBuf 组成 ...
						// 只要有数据可以写、这里 会尝试写更多 ~、这里是计算一个计数
            int maxBytesPerGatheringWrite = ((NioSocketChannelConfig) config).getMaxBytesPerGatheringWrite(); // 293976
            // 返回数组中NIO缓冲区的数量和NIO缓冲区的可读字节总数 , 暂时理解就是要写的 
						// 3. 这里的 ByteBuffer 来自与 FastThreadLocal, 线程内内存复用
            ByteBuffer[] nioBuffers = in.nioBuffers(1024, maxBytesPerGatheringWrite);
            int nioBufferCnt = in.nioBufferCount();

            // 根据 nioBufferCnt 进行优化
            switch (nioBufferCnt) {
                case 0:
                    // We have something else beside ByteBuffers to write so fallback to normal writes.
                    writeSpinCount -= doWrite0(in);
                    break;
                case 1: {
                    // Only one ByteBuf so use non-gathering write ; 只有1个、走 non-gathering 写
                    // Zero length buffers are not added to nioBuffers by ChannelOutboundBuffer, so there is no need
                    // to check if the total size of all the buffers is non-zero.

											// 不需要使用聚集写方法 . gathering write . java 本身支持的。调用的方法不同而已
                    ByteBuffer buffer = nioBuffers[0];
                    int attemptedBytes = buffer.remaining();
                    final int localWrittenBytes = ch.write(buffer);
                    if (localWrittenBytes <= 0) {
                        incompleteWrite(true);
                        return;
                    }
                    adjustMaxBytesPerGatheringWrite(attemptedBytes, localWrittenBytes, maxBytesPerGatheringWrite);
                    in.removeBytes(localWrittenBytes);
                    --writeSpinCount;
                    break;
                }
                default: {
                    // Zero length buffers are not added to nioBuffers by ChannelOutboundBuffer, so there is no need
                    // to check if the total size of all the buffers is non-zero.
                    // We limit the max amount to int above so cast is safe
                    long attemptedBytes = in.nioBufferSize(); //?
                    final long localWrittenBytes = ch.write(nioBuffers, 0, nioBufferCnt);
                    if (localWrittenBytes <= 0) {
                        incompleteWrite(true);
                        return;
                    }
                    // Casting to int is safe because we limit the total amount of data in the nioBuffers to int above.
                    adjustMaxBytesPerGatheringWrite((int) attemptedBytes, (int) localWrittenBytes,
                            maxBytesPerGatheringWrite);
                    // 这里会根据字节来触发
                    in.removeBytes(localWrittenBytes);
                    --writeSpinCount;
                    break;
                }
            }
        } while (writeSpinCount > 0);            

        // 如果 writeSpinCount <0 == true 意味着写不进去了，这里会注册一个 OP_WRITE 事件
        incompleteWrite(writeSpinCount < 0);
    }
```


- 需要的写的数据量可能也很大，也是非阻塞，所以类似读，也会连写 16次，自动调整需要的内存 ;
- 这里和读不一样，自己实现一个 生产者-消费者的 队列模型, 高低水位的算法，完全没有使用 `OP_WRITE` 事件, 减少对操作系统的压力