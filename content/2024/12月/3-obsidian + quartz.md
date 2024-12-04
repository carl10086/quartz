
## 1-Intro

一个免费的 obsidian publish 方案.


**1)-先初始化**

```bash
nvm use v20.18.1
git clone https://github.com/jackyzha0/quartz.git
cd quartz
npm inpx 
quartz create
```


**2)-初始化之后**

```sh
npx quartz build --serve
```

可以本地预览


**3)-Hosts 方案**

支持如下的4种姿势:
1. Cloudflare Pages
2. GitHub Pages
3. Custom Domain
4. Vercel
5. GitLab Pages
6. Self-Hosting

## 2-Cloudflare pages

我们使用 `Cloudflare pages` 功能.


1. Log in to the [Cloudflare dashboard](https://dash.cloudflare.com/) and select your account.
2. In Account Home, select **Workers & Pages** > **Create application** > **Pages** > **Connect to Git**.
3. Select the new GitHub repository that you created and, in the **Set up builds and deployments** section, provide the following information:

|Configuration option|Value|
|---|---|
|Production branch|`v4`|
|Framework preset|`None`|
|Build command|`npx quartz build`|
|Build output directory|`public`|

即可.





## refer

- [Quartz v4](https://quartz.jzhao.xyz/)