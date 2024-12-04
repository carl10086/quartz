


## refer

- [primevue3](https://primevue.org/)


## 1-Basic


随便找一个主题，二次开发的组件. 例如:

```sh
git clone https://github.com/primefaces/sakai-vue.git
```


标准的 `vue` 项目配置.

```
sakai-vue/
├── public/          # 静态资源
├── src/
│   ├── assets/     # 项目资源文件
│   ├── components/ # Vue 组件
│   ├── layout/     # 布局组件
│   ├── router/     # 路由配置
│   ├── service/    # API 服务
│   └── views/      # 页面视图
├── package.json    # 项目配置
└── vite.config.js  # Vite 配置
```


- `PrimeVue` 和 `Vue3`
- 包含了响应式的布局



**1)-侧边栏**

- `AppMenu.vue` : 定制侧边栏
- `index.js` : `path` 到 `Components` 的路由


**2)-icons

[官方的 icon](https://primevue.org/icons/)

**3)-多环境**

`.env.development` 文件增加内容:

```sh
VITE_APP_SERVER=http://localhost:10013
```

```javascript
import axios from 'axios';

/**
 * 定义 athena link server 访问的 客户端
 * @type {axios.AxiosInstance}
 */
export const api = axios.create({
    baseURL: `${import.meta.env.VITE_APP_SERVER}`,
    withCredentials: true // 配置axios发送请求时携带cookie
});

api.interceptors.response.use(
    function (response) {
        const data = response.data;
        // console.log('Response data:', JSON.stringify(data, null, 4));
        const code = data.code;
        if (code === 200) {
            return data.data;
        }

        if (code === 400) {
            console.log('Handling 400 error:', data.message); // 调试日志
            const error = new Error(data.message);
            error.code = code;
            error.reqId = data.reqId; // 可选：保存请求ID
            return Promise.reject(error);
        }

        // 其他错误情况
        return Promise.reject(new Error(data.message || 'Unknown error'));
    },
    function (error) {
        return Promise.reject(error);
    }
);
```


**4)-弹出框**

确认 `main.js` 中使用: 

```javascript
app.use(ConfirmationService);
```

确认 `App.vue` 中使用 ConfirmDialog

```javascript
<script setup>  
import ConfirmDialog from 'primevue/confirmdialog';  
</script>  
  
<template>  
    <confirm-dialog/>    <router-view /></template>  
  
<style scoped></style>
```

然后所有的模块中 就可以用 `confirm`

## 2-CORS

开发环境的解决方案是 前端自己代理 ;
线上环境的解决方案是 `NGINX` 配置一些 `HEADER` ;

```javascript
import { fileURLToPath, URL } from 'node:url';  
  
import { PrimeVueResolver } from '@primevue/auto-import-resolver';  
import vue from '@vitejs/plugin-vue';  
import Components from 'unplugin-vue-components/vite';  
import { defineConfig } from 'vite';  
  
// https://vitejs.dev/config/  
export default defineConfig(({ command, mode }) => {  
    // 加载环境变量  
    // const env = loadEnv(mode, process.cwd());  
  
    // 基础配置  
    const config = {  
        optimizeDeps: {  
            noDiscovery: true  
        },  
        plugins: [  
            vue(),  
            Components({  
                resolvers: [PrimeVueResolver()]  
            })  
        ],  
        resolve: {  
            alias: {  
                '@': fileURLToPath(new URL('./src', import.meta.url))  
            }  
        }  
    };  
  
    // 开发环境添加代理配置  
    if (command === 'serve' || mode === 'development') {  
        config.server = {  
            port: 3000, // 可以根据需要修改端口  
            proxy: {  
                '/link': {  
                    target: 'http://localhost:10013',  
                    changeOrigin: true,  
                    rewrite: (path) => path.replace(/^\/link/, ''),  
                    secure: false  
                }  
            }  
        };  
    }  
  
    return config;  
});
```

然后, `.env.development` 改为如下的设计:

```yaml
# VITE_APP_LINK_SERVER=http://localhost:10013  
VITE_APP_LINK_SERVER=/link
```


## 3-VITE PREFIX

```nginx.conf
 server {
     listen 8081;
     server_name localhost;

     include mime.types;
     default_type application/octet-stream;

     location /admin {
         alias {YOUR-DIST-DIR};
         index index.html;
         try_files $uri $uri/ /admin/index.html;

         # 确保正确的 MIME 类型
         location ~* \.(js)$ {
             add_header Content-Type application/javascript;
         }
     }
 }
```

- 假设 `prefix` 是 `admin`

前端工程改造. `index.js`

```javascript
const router = createRouter({  
    history: createWebHistory('/admin/'),
    ..
```


改造 `vite.config.js` 

```javascript
const config = {  
    // 非 local 环境build 需要 admin 前缀  
    base: '/admin/',
    ...
```


