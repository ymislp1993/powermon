CORE := Sources/core/*.swift
CLI := Sources/cli/*.swift
APP := Sources/app/*.swift

# CLI：powermon now / record（行为与 M1 一致）
powermon:
	swiftc -O $(CORE) $(CLI) -o powermon

# 图标：CoreGraphics 生成 1024px → iconset → icns
icon:
	cd packaging && swift gen_icon.swift && mkdir -p AppIcon.iconset && \
	for s in 16 32 128 256 512; do \
		sips -z $$s $$s AppIcon_1024.png --out AppIcon.iconset/icon_$${s}x$${s}.png >/dev/null; \
		d=$$((s*2)); sips -z $$d $$d AppIcon_1024.png --out AppIcon.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done && iconutil -c icns AppIcon.iconset -o AppIcon.icns

# 菜单栏 app：build/PowerMon.app（LSUIElement，ad-hoc 签名，带图标）
app: icon
	mkdir -p build/PowerMon.app/Contents/MacOS build/PowerMon.app/Contents/Resources
	swiftc -O -parse-as-library $(CORE) $(APP) -o build/PowerMon.app/Contents/MacOS/PowerMon
	cp packaging/Info.plist build/PowerMon.app/Contents/Info.plist
	cp packaging/AppIcon.icns build/PowerMon.app/Contents/Resources/AppIcon.icns
	printf 'APPL????' > build/PowerMon.app/Contents/PkgInfo
	codesign --force -s - build/PowerMon.app

# 正式安装：装进 /Applications（Spotlight/Launchpad 可见），迁移运行实例
install: app
	pkill -x PowerMon 2>/dev/null || true
	rm -rf "/Applications/PowerMon.app"
	cp -R build/PowerMon.app /Applications/
	touch /Applications/PowerMon.app
	open /Applications/PowerMon.app

clean:
	rm -rf powermon build

.PHONY: powermon icon app install clean
