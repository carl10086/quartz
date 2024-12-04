# 定义源目录和目标目录
SRC_DIR := "/Users/carlyu/Library/Mobile Documents/iCloud~md~obsidian/Documents/obs_notes/carl-blogs"
CONTENT_DIR := content

.PHONY: sync clean build deploy

# 默认任务
all: sync build

# 同步内容
sync:
	@echo "Syncing content..."
	@rm -rf $(CONTENT_DIR)
	@cp -r $(SRC_DIR) $(CONTENT_DIR)
	@echo "Content synced!"
