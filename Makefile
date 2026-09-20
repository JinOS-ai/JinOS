# jinOs@ai — build and run. See ROADMAP.md (Phase 0) and docs/dev-environment.md.
#
#   make image       build build/jinos.raw
#   make run         boot it in QEMU (window + serial on this terminal)
#   make run-serial  boot with serial console only
#   make ssh         ssh into the running VM (dev profile: jin / jinos)
#   make boot-test   headless boot, pass if a login prompt appears
#   make clean       remove build/

PROFILE    ?= dev
MKOSI_ARGS ?=
BUILD_DIR  := $(CURDIR)/build
IMAGE      := $(BUILD_DIR)/jinos.raw

# Where mkosi runs: natively when this is Linux with mkosi installed,
# otherwise inside the Debian 13 builder container (docker/podman).
# Force one with MKOSI=native or MKOSI=container.
ifeq ($(shell uname -s),Linux)
  MKOSI ?= $(if $(shell command -v mkosi 2>/dev/null),native,container)
else
  MKOSI ?= container
endif
ifeq ($(MKOSI),native)
  MKOSI_CMD := mkosi
else
  MKOSI_CMD := tools/mkosi-in-container.sh
endif
MKOSI_INVOKE := $(MKOSI_CMD) --directory base --profile=$(PROFILE) $(MKOSI_ARGS)

.PHONY: image summary run run-serial ssh boot-test clean

image:
	$(MKOSI_INVOKE) build

summary:
	$(MKOSI_INVOKE) summary

run:
	tools/run-qemu.sh $(IMAGE)

run-serial:
	JINOS_DISPLAY=none tools/run-qemu.sh $(IMAGE)

ssh:
	ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null jin@localhost

boot-test:
	tools/boot-test.sh $(IMAGE)

clean:
	rm -rf $(BUILD_DIR)
