TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VolumeDownFloater
VolumeDownFloater_FILES = Tweak.xm
VolumeDownFloater_CFLAGS = -fobjc-arc
VolumeDownFloater_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk