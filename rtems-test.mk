
CFE_IMG_MB ?= 32
CPUNAME ?= cpu1
O ?= build
INSTALL_DIR ?= $(O)/exe
CFE_DISK_IMG ?= $(INSTALL_DIR)/$(CPUNAME)/nonvol-disk.img
CFE_FS_IMG ?= $(INSTALL_DIR)/$(CPUNAME)/nonvol-fs.img
QEMU_COMMAND ?= qemu-system-i386 -m 128

ALL_OSAL_TESTS :=          	\
    bin-sem-flush-test		\
    bin-sem-test			\
    bin-sem-timeout-test	\
    count-sem-test			\
    file-api-test			\
    file-sys-add-fixed-map-api-test	\
    idmap-api-test			\
    mutex-test				\
    osal-core-test			\
    queue-timeout-test		\
    sem-speed-test			\
    symbol-api-test			\
    time-base-api-test		\
    timer-add-api-test		\
    timer-test				\
    osal_core_UT           \
    osal_filesys_UT        \
    osal_file_UT           \
    osal_loader_UT         \
    osal_network_UT        \
    osal_timer_UT          \
    # broken network-api-test		\
    # select-test		        \

ALL_CFE_COVERAGE_TESTS := 			\
	cfe-core_es_UT     \
    cfe-core_evs_UT    \
    cfe-core_fs_UT     \
    cfe-core_sb_UT     \
    cfe-core_tbl_UT    \
    cfe-core_time_UT 
ALL_OSAL_COVERAGE_TESTS :=                      \
	coverage-shared-binsem-testrunner			\
    coverage-shared-clock-testrunner            \
    coverage-shared-common-testrunner           \
    coverage-shared-countsem-testrunner         \
    coverage-shared-dir-testrunner              \
    coverage-shared-errors-testrunner           \
    coverage-shared-filesys-testrunner          \
    coverage-shared-file-testrunner             \
    coverage-shared-heap-testrunner             \
    coverage-shared-idmap-testrunner            \
    coverage-shared-module-testrunner           \
    coverage-shared-mutex-testrunner            \
    coverage-shared-network-testrunner          \
    coverage-shared-printf-testrunner           \
    coverage-shared-queue-testrunner            \
    coverage-shared-select-testrunner           \
    coverage-shared-sockets-testrunner          \
    coverage-shared-task-testrunner             \
    coverage-shared-timebase-testrunner         \
    coverage-shared-time-testrunner             \
    coverage-vxworks-binsem-testrunner          \
    coverage-vxworks-bsd-select-testrunner      \
    coverage-vxworks-common-testrunner          \
    coverage-vxworks-console-bsp-testrunner     \
    coverage-vxworks-console-testrunner         \
    coverage-vxworks-countsem-testrunner        \
    coverage-vxworks-dirs-globals-testrunner    \
    coverage-vxworks-files-testrunner           \
    coverage-vxworks-filesys-testrunner         \
    coverage-vxworks-heap-testrunner            \
    coverage-vxworks-idmap-testrunner           \
    coverage-vxworks-loader-testrunner          \
    coverage-vxworks-mutex-testrunner           \
    coverage-vxworks-network-testrunner         \
    coverage-vxworks-no-loader-testrunner       \
    coverage-vxworks-no-shell-testrunner        \
    coverage-vxworks-posix-files-testrunner     \
    coverage-vxworks-posix-dirs-testrunner      \
    coverage-vxworks-posix-gettime-testrunner   \
    coverage-vxworks-posix-io-testrunner        \
    coverage-vxworks-queues-testrunner          \
    coverage-vxworks-shell-testrunner           \
    coverage-vxworks-symtab-testrunner          \
    coverage-vxworks-tasks-testrunner           \
    coverage-vxworks-timebase-testrunner        \
	coverage-ut-mcp750-vxworks-testrunner


ALL_CFE_TEST_LIST := $(addprefix $(INSTALL_DIR)/$(CPUNAME)/, \
    $(ALL_CFE_COVERAGE_TESTS)                            \
)

ALL_OS_TEST_LIST := $(addprefix $(INSTALL_DIR)/$(CPUNAME)/, \
    $(ALL_OSAL_COVERAGE_TESTS)                           \
    $(ALL_OSAL_TESTS)                                    \
)

ALL_TEST_LIST := $(ALL_CFE_TEST_LIST) $(ALL_OS_TEST_LIST)

MACADDR = 00:04:9F$(shell head -c 3 /dev/urandom | hexdump -v -e '/1 ":%02X"')

.PHONY: all run all_tests all_logs cfe-disk 
#$(addsuffix .check,$(ALL_TEST_LIST)))
#.INTERMEDIATE: $(CFE_FS_IMG)
.SECONDARY: $(addsuffix .log,$(ALL_TEST_LIST)))

all: cfe-disk
cfe-disk: $(CFE_DISK_IMG).stamp

$(CFE_DISK_IMG): FS_SIZE := $(shell echo $$(($(CFE_IMG_MB) * 1048576)))

$(CFE_DISK_IMG):
	truncate -s $(FS_SIZE)  $(@)
	parted -s $(@) -- mklabel msdos
	parted -a none -s $(@) -- mkpart primary fat32 63s -1s

$(CFE_FS_IMG): 
	truncate -s $$((($(CFE_IMG_MB) * 1048576) - 32256))  $(@)
	mkfs.fat $(@)
	mcopy -i $(@) -sv $(O)/i686-rtems5/default_cpu1/osal/unit-tests/osloader-test/utmod :: || /bin/true
	mcopy -i $(@) -sv $(INSTALL_DIR)/$(CPUNAME)/eeprom ::

$(CFE_DISK_IMG).stamp: $(CFE_DISK_IMG) $(CFE_FS_IMG)
	dd if=$(CFE_FS_IMG) of=$(CFE_DISK_IMG) bs=512 seek=63
	touch $(@)

run: $(CFE_DISK_IMG).stamp
	$(QEMU_COMMAND) -display none -no-reboot -serial mon:stdio \
	    -kernel $(INSTALL_DIR)/$(CPUNAME)/$(KERNEL_NAME).exe \
	    -drive file=$(CFE_DISK_IMG),format=raw \
    	-device i82557b,netdev=net0,mac=$(MACADDR) \
	    -netdev user,id=net0,hostfwd=udp:127.0.0.1:1235-:1235 \
		-append '--console=/dev/com1'

clean:
	rm -f $(INSTALL_DIR)/*.img $(INSTALL_DIR)/*.stamp \
		$(addsuffix .check,$(ALL_TEST_LIST)) \
		$(addsuffix .log,$(ALL_TEST_LIST))

%.cow: $(CFE_DISK_IMG).stamp
	qemu-img create -o backing_file=$(notdir $(CFE_DISK_IMG)),backing_fmt=raw -f qcow2 $(@)
	
%.log: %.exe %.cow
	$(QEMU_COMMAND) -no-reboot -display none \
	    -kernel $(<) \
	    -append '--batch-mode' \
	    -drive file=$(*).cow,format=qcow2 \
	    -device i82557b,netdev=net0,mac=$(MACADDR) \
	    -netdev user,id=net0 \
	    -serial file:$(@)

%.check: %.log
	@(grep -q '^Application exit status: SUCCESS' $(<)) || (echo $(*): ---FAIL---; /bin/false )
	
all_logs: $(addsuffix .log,$(ALL_TEST_LIST))
all_cfe_logs: $(addsuffix .log,$(ALL_CFE_TEST_LIST))
all_tests: $(addsuffix .check,$(ALL_TEST_LIST))
	@echo  '*** SUCCESS ***'

all_cfe_tests: $(addsuffix .check,$(ALL_CFE_TEST_LIST))
	@echo  '*** SUCCESS ***'


