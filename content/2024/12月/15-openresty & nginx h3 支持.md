
## 1-介绍

**1)-基本条件**

使用 *apt* 直接安装

```shell
apt-get install libpcre3-dev  libssl-dev perl make build-essential curl
```

或者用源码编译, 然后指定 安装位置

```shell
$ ./configure \
   --with-cc-opt="-I/usr/local/opt/openssl/include/ -I/usr/local/opt/pcre/include/" \
   --with-ld-opt="-L/usr/local/opt/openssl/lib/ -L/usr/local/opt/pcre/lib/" \
   -j8
```

**2)-基本安装**

```shell
./configure --prefix=/opt/openresty \
            --with-pcre-jit \
            --with-ipv6 \
            --without-http_redis2_module \
            --with-http_iconv_module \
            --with-http_postgres_module \
            -j8
```

- `--prefix` : 指定安装路径
- `--with-pcre-jit` : 启用 PCRE JIT 支持
- `--with-ipv6`
- `--without-http_redis2_module`: 禁用了 `Redis2` 模块
- `--with-http-iconv_module` : 启用字符集转换模块
- `--with-http_postgres_module`: 启用 `PostgreSQL` 模块
- 使用 8个并行编译进程


## 2-nginx 安装

### h3 支持

比较建议的 使用支持 `QUIC` 的 `SSL` 库来构建 `nginx`, 这里说的是 `BoringSSL`, `LibreSSL` 或者 `QuicTLS`, 否则只能使用 `OpenSSL` 的兼容层, 它不太支持 `early data` 功能.

*1)-使用 BoringSSL 的配置*

```shell
./configure
    --with-debug
    --with-http_v3_module
    --with-cc-opt="-I../boringssl/include"
    --with-ld-opt="-L../boringssl/build/ssl
                   -L../boringssl/build/crypto"
```

*2)-使用 QuicTLS 的配置*

```shell
./configure
    --with-debug
    --with-http_v3_module
    --with-cc-opt="-I../quictls/build/include"
    --with-ld-opt="-L../quictls/build/lib"
```

*3)-使用 LibreSSL 的配置*

```shell
./configure
    --with-debug
    --with-http_v3_module
    --with-cc-opt="-I../libressl/build/include"
    --with-ld-opt="-L../libressl/build/lib"
```

我们使用 `boring SSL` 来实现.

```shell
git clone https://boringssl.googlesource.com/boringssl
```


```shell
sudo apt install libpcre3-dev zlib1g-dev
```


```shell
./configure \
    --sbin-path=/home/carl/sys/nginx/nginx \
    --conf-path=/home/carl/sys/nginx/nginx.conf \
    --pid-path=/home/carl/logs/nginx/nginx.pid \
    --with-file-aio \
    --with-debug \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_v3_module \
    --with-openssl=/home/carl/opt/openssl-openssl-3.4.0 \
    --with-cc-opt="-I /home/carl/opt/boringssl/include" \
    --with-ld-opt="-L /home/carl/opt/boringssl/build/ssl -L /home/carl/opt/boringssl/build/crypto"
```


> [!NOTE] Notes
> 这里有 `TLS` 编译冲突, 如果提前有 `OpenSSL` 提前安装，解决起来比较麻烦，可以考虑用 `Docker` 解决

```shell
./configure \
    --sbin-path=/home/carl/sys/nginx/nginx \
    --conf-path=/home/carl/sys/nginx/nginx.conf \
    --pid-path=/home/carl/logs/nginx/nginx.pid \
    --with-file-aio \
    --with-debug \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_v3_module \
    --with-openssl=/home/carl/opt/openssl-openssl-3.4.0 
```


### 自签名测试

```shell
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = CN
ST = Beijing
L = Beijing
O = Development
OU = Dev Team
CN = dev.local

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = dev.local
DNS.2 = *.dev.local
DNS.3 = api.dev.local
DNS.4 = admin.dev.local
IP.1 = 124.221.218.173
```

```shell
## 1. 生成证书
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout private.key \
    -out certificate.crt \
    -config ssl.conf

## 2. 查看证书信息
openssl x509 -in certificate.crt -text -noout

## 3. 验证私钥匹配
openssl rsa -in private.key -check

## 4. 验证证书链
openssl verify -CAfile certificate.crt certificate.crt

## 5. 检查证书是否支持域名 和 IP
openssl x509 -in certificate.crt -noout -text | grep DNS
openssl x509 -in certificate.crt -noout -text | grep IP

## 6. 检查证书的有效期
openssl x509 -in certificate.crt -noout -dates
```

### 特权端口

```shell
# 给 frpc 二进制文件授予绑定特权端口的能力
sudo setcap cap_net_bind_service=+ep /path/to/frpc

# 验证权限
getcap /path/to/frpc
```


## refer

- [Nginx Installation](https://nginx.org/en/docs/configure.html)
- [Nginx Http3 enable](https://nginx.org/en/docs/quic.html)