TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GloryKey

GloryKey_FILES = Tweak.x GloryKeyUI.m AntiDebug.m
GloryKey_CFLAGS = -fobjc-arc
GloryKey_FRAMEWORKS = UIKit Foundation Security CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
