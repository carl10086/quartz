

## 1-Intro


有一些简单的工具类，但是感觉 `tomcat` 的内部实现更加的靠谱，这里分析一下源码.

**1)-简单实现**

检查一下简单的 `HTTP-HEADER`

```java
public static String getIP(HttpServletRequest request) {  
    Assert.notNull(request, "HttpServletRequest is null");  
    String ip = request.getHeader("X-Requested-For");  
    if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {  
        ip = request.getHeader("X-Forwarded-For");  
    }  
  
    if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {  
        ip = request.getHeader("Proxy-Client-IP");  
    }  
  
    if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {  
        ip = request.getHeader("WL-Proxy-Client-IP");  
    }  
  
    if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {  
        ip = request.getHeader("HTTP_CLIENT_IP");  
    }  
  
    if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {  
        ip = request.getHeader("HTTP_X_FORWARDED_FOR");  
    }  
  
    if (StrUtil.isBlank(ip) || "unknown".equalsIgnoreCase(ip)) {  
        ip = request.getRemoteAddr();  
    }  
  
    return StrUtil.isBlank(ip) ? null : ip.split(",")[0];  
}

```

**2)-TOMCAT 源码分析**

源码位置: 

- `org.apache.catalina.filters.RemoteIpFilter#doFilter(jakarta.servlet.http.HttpServletRequest, jakarta.servlet.http.HttpServletResponse, jakarta.servlet.FilterChain)`



**3)-理解一次代理的行为**

假设只有一层代理 `NGINX`, 然后用户通过浏览器访问 `https://www.example.com` . 然后会有如下的问题:

1. `Web` 服务器如何知道 原始的请求是 `HTTPS` ;
2. `Web` 服务器如何知道用户实际上访问的是 `www.example.com`

而代理服务器有一些契约的.

- `X-Forwarded-Proto` : 会说明  `Web` 服务器原始请求使用的协议（`HTTP` 或 `HTTPS`）;
- `X-Forwarded-Host`  : 会告诉 `Web` 服务器原始访问的 `Host` 是什么 ;




## 2-Design


### 2-1 内部代理网段


```java
private Pattern internalProxies =  
        Pattern.compile("10\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}|" + "192\\.168\\.\\d{1,3}\\.\\d{1,3}|" +  
                "169\\.254\\.\\d{1,3}\\.\\d{1,3}|" + "127\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}|" +  
                "100\\.6[4-9]{1}\\.\\d{1,3}\\.\\d{1,3}|" + "100\\.[7-9]{1}\\d{1}\\.\\d{1,3}\\.\\d{1,3}|" +  
                "100\\.1[0-1]{1}\\d{1}\\.\\d{1,3}\\.\\d{1,3}|" + "100\\.12[0-7]{1}\\.\\d{1,3}\\.\\d{1,3}|" +  
                "172\\.1[6-9]{1}\\.\\d{1,3}\\.\\d{1,3}|" + "172\\.2[0-9]{1}\\.\\d{1,3}\\.\\d{1,3}|" +  
                "172\\.3[0-1]{1}\\.\\d{1,3}\\.\\d{1,3}|" + "0:0:0:0:0:0:0:1|::1");
```



`IANA` 把这些网段保留为私有网段. 

- 10.0.0.0 到 10.255.255.255
- 192.168.0.0 到 192.168.255.255
- 169.254.0.0 到 169.254.255.255
- 127.0.0.0 到 127.255.255.255
- 100.64.0.0 到 100.127.255.255
- 172.16.0.0 到 172.31.255.255
- ::1 和 0:0:0:0:0:0:0:1 (IPv6 回环地址)

因为 `Java` 一般是后端网络，前面一般是 `NGINX` 等等 `PROXY` .



```java
public XForwardedRequest(HttpServletRequest request) {  
    super(request);  
    this.localName = request.getLocalName();  
    this.localPort = request.getLocalPort();  
    this.remoteAddr = request.getRemoteAddr();  
    this.remoteHost = request.getRemoteHost();  
    this.scheme = request.getScheme();  
    this.secure = request.isSecure();  
    this.serverName = request.getServerName();  
    this.serverPort = request.getServerPort();  
  
    headers = new HashMap<>();  
    for (Enumeration<String> headerNames = request.getHeaderNames(); headerNames.hasMoreElements();) {  
        String header = headerNames.nextElement();  
        headers.put(header, Collections.list(request.getHeaders(header)));  
    }  
}
```


- `request` 信息复制

### 2-2 解析 `X-Forwarded-For` 头

```java
for (idx = remoteIpHeaderValue.length - 1; idx >= 0; idx--) {
    String currentRemoteIp = remoteIpHeaderValue[idx];
    remoteIp = currentRemoteIp;
    if (internalProxies != null && internalProxies.matcher(currentRemoteIp).matches()) {
        // 内部代理 IP，继续向左查找
    } else if (trustedProxies != null && trustedProxies.matcher(currentRemoteIp).matches()) {
        // 可信代理 IP，添加到代理链中
        proxiesHeaderValue.addFirst(currentRemoteIp);
    } else {

        // 找到第一个非内部非可信的 IP，认为是客户端 IP
        break;
    }
}
```


从右向左遍历，找到第一个 非内部的 `IP`

### 2-3 解析 `X-Forwarded-By` 头

```java
if (remoteIp != null) {  
  
    xRequest.setRemoteAddr(remoteIp);  
    if (getEnableLookups()) {  
        // This isn't a lazy lookup but that would be a little more  
        // invasive - mainly in XForwardedRequest - and if        // enableLookups is true is seems reasonable that the        // hostname will be required so look it up here.        try {  
            InetAddress inetAddress = InetAddress.getByName(remoteIp);  
            // We know we need a DNS look up so use getCanonicalHostName()  
            xRequest.setRemoteHost(inetAddress.getCanonicalHostName());  
        } catch (UnknownHostException e) {  
            log.debug(sm.getString("remoteIpFilter.invalidRemoteAddress", remoteIp), e);  
            xRequest.setRemoteHost(remoteIp);  
        }  
    } else {  
        xRequest.setRemoteHost(remoteIp);  
    }  
  
    if (proxiesHeaderValue.size() == 0) {  
        xRequest.removeHeader(proxiesHeader);  
    } else {  
        String commaDelimitedListOfProxies = StringUtils.join(proxiesHeaderValue);  
        xRequest.setHeader(proxiesHeader, commaDelimitedListOfProxies);  
    }  
    if (newRemoteIpHeaderValue.size() == 0) {  
        xRequest.removeHeader(remoteIpHeader);  
    } else {  
        String commaDelimitedRemoteIpHeaderValue = StringUtils.join(newRemoteIpHeaderValue);  
        xRequest.setHeader(remoteIpHeader, commaDelimitedRemoteIpHeaderValue);  
    }  
}
```



### 2-4 解析 protocolHeader 头



```java
if (protocolHeader != null) {  
    String protocolHeaderValue = request.getHeader(protocolHeader);  
    if (protocolHeaderValue == null) {  
        // Don't modify the secure, scheme and serverPort attributes  
        // of the request    } else if (isForwardedProtoHeaderValueSecure(protocolHeaderValue)) {  
        xRequest.setSecure(true);  
        xRequest.setScheme("https");  
        setPorts(xRequest, httpsServerPort);  
    } else {  
        xRequest.setSecure(false);  
        xRequest.setScheme("http");  
        setPorts(xRequest, httpServerPort);  
    }  
}
```


- 根据这个头，重新设置 `http` 还是 `https`

### 2-5 解析 hostHeader


```java
if (hostHeader != null) {  
    String hostHeaderValue = request.getHeader(hostHeader);  
    if (hostHeaderValue != null) {  
        try {  
            int portIndex = Host.parse(hostHeaderValue);  
            if (portIndex > -1) {  
                log.debug(sm.getString("remoteIpFilter.invalidHostWithPort", hostHeaderValue, hostHeader));  
                hostHeaderValue = hostHeaderValue.substring(0, portIndex);  
            }  
  
            xRequest.setServerName(hostHeaderValue);  
            if (isChangeLocalName()) {  
                xRequest.setLocalName(hostHeaderValue);  
            }  
  
        } catch (IllegalArgumentException iae) {  
            log.debug(sm.getString("remoteIpFilter.invalidHostHeader", hostHeaderValue, hostHeader));  
        }  
    }  
}
```


## 3-Conclusion

通过 `Wrapper` 的方式去搞定 . `X-Forwarded-Proto` `X-Forwarded-Host` 和 `X-Forwarded-For` 头 .

考虑了 内网网段, `HTTPS` 等等方式，相对比较完善