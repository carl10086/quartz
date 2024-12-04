

## Refer

- [playright](https://github.com/microsoft/playwright)

微软的自动化测试工具， 好像做爬虫也厉害的.


## 1-Intro

从功能场景上类似 `Selenium` , `Pyppeteer` 等, 都可以驱动浏览器进行各种 自动化操作.  *比较新*, 也比较强大

1. `Playwright` 支持当前基本所有的主流浏览器, 包括 `Chrome` 和 `Edge` , `Firefox`, `Safari(基于 WebKit)` 的版本, 提供完善的自动化控制的 `API`
2. `Playwright` 支持所有浏览器的 `Headless` 模式和 非 `Headless` 模式的测试
3. 支持非常方便的工具链:
	- [Codegen](https://playwright.dev/docs/codegen):  通过记录你的 `actions` 来生成测试代码
	- [Playwright inspector](https://playwright.dev/docs/debug) : Inspect page, generate selectors, step through the test execution, see click points and explore execution logs.
	- [Trace-viewer](https://playwright.dev/docs/trace-viewer): Capture all the information to investigate the test failure. Playwright trace contains test execution screencast, live DOM snapshots, action explorer, test source and many more.

甚至有其他各种的语言的版本， 包括: `TypeScript`, `JavaScript` , `Python` , `.NET` , `Java`


## 2-Quickstart

可以基于 `pip` 或者 `conda` , 安装后，执行 `playwright install` 下载驱动即可.

- 基于 `pip` 的方式

```bash
pip3 install --upgrade pip
pip3 install playwright
playwright install
```


- 基于 `conda` 的方式

```sh
conda config --add channels conda-forge
conda config --add channels microsoft
conda install playwright
playwright install
```


```python
from playwright.sync_api import sync_playwright  
import time  
  
  
def test_book_access():  
    with sync_playwright() as p:  
        browser = p.chromium.launch(headless=False)  
        context = browser.new_context(  
            viewport={'width': 1280, 'height': 800},  
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'  
        )  
  
        page = context.new_page()  
  
        try:  
            # 1. 访问入口页面并点击目标链接  
            print("访问入口页面...")  
            page.goto("https://jc.pep.com.cn/?filed=%E5%B0%8F%E5%AD%A6&subject=%E8%8B%B1%E8%AF%AD")  
            page.wait_for_load_state('networkidle')  
  
            links = page.query_selector_all('a')  
            target_url = "https://book.pep.com.cn/1212001201133"  
  
            found = False  
            for link in links:  
                href = link.get_attribute('href')  
                if href and target_url in href:  
                    print(f"找到目标链接: {href}")  
                    with page.expect_popup() as popup_info:  
                        link.click()  
                    new_page = popup_info.value  
                    found = True  
                    break  
            if not found:  
                print("未找到目标链接")  
                return  
  
            # 2. 等待新页面加载  
            print("等待新页面加载...")  
            new_page.wait_for_load_state('networkidle')  
            new_page.wait_for_timeout(5000)  
  
            # 3. 开始翻页循环  
            page_num = 1  
            while True:  
                try:  
                    print(f"当前第 {page_num} 页")  
  
                    # 保存当前页面截图  
                    new_page.screenshot(path=f"page_{page_num:03d}.png", full_page=True)  
                    print(f"已保存第 {page_num} 页截图")  
  
                    # 通过CSS选择器定位下一页按钮  
                    # 这里使用多个可能的选择器  
                    next_button = new_page.locator('''  
                        .buttonBar .button[style*="left: 1083px"],                        .buttonBar div:has(span:text("下一页")),  
                        .button:has(img[src*="next"])                    ''').first  
  
                    if next_button.is_visible():  
                        print("找到下一页按钮，准备点击")  
                        # 使用evaluate来模拟点击  
                        next_button.evaluate('button => button.click()')  
                        print("点击下一页按钮")  
                        # 等待页面切换动画和内容加载  
                        new_page.wait_for_timeout(2000)  
  
                        # 检查页面是否真的切换了  
                        old_screenshot = f"page_{page_num:03d}.png"  
                        page_num += 1  
                        new_screenshot = f"page_{page_num:03d}.png"  
                        new_page.screenshot(path=new_screenshot)  
  
                        print(f"已保存新页面截图: {new_screenshot}")  
                    else:  
                        print("未找到下一页按钮，尝试其他方法...")  
  
                        # 打印页面上所有的按钮元素，帮助调试  
                        buttons = new_page.evaluate('''() => {  
                            const buttons = document.querySelectorAll('.button');                            return Array.from(buttons).map(button => ({                                text: button.innerText,                                style: button.getAttribute('style'),                                html: button.innerHTML                            }));                        }''')  
  
                        print("页面上的按钮元素：")  
                        for idx, btn in enumerate(buttons):  
                            print(f"按钮 {idx + 1}:")  
                            print(f"  文本: {btn['text']}")  
                            print(f"  样式: {btn['style']}")  
                            print(f"  HTML: {btn['html']}")  
  
                        break  
  
                except Exception as e:  
                    print(f"翻页过程中发生错误: {str(e)}")  
                    new_page.screenshot(path=f"error_page_{page_num}.png")  
                    break  
  
            print(f"总共处理了 {page_num} 页")  
            new_page.wait_for_timeout(3000)  
  
        except Exception as e:  
            print(f"发生错误: {str(e)}")  
  
        finally:  
            browser.close()  
  
  
if __name__ == "__main__":  
    test_book_access()
```


这个代码会爬一个复杂的页面.


1. 从搜索页面开始 ;
2. 找到对应的教材，点击 `click` ;
3. 进入教材页面之后，通过 class 查找下一页，然后每页都保存一下就 `OK` ;