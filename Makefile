# Simple Makefile for Bluespec SystemVerilog Testing
# =============================================================================

# Compiler and tools
BSC = bsc
RM = rm -rf

# Source directories
CORDIC_SRC_DIR = cordic
RECIPROCAL_SRC_DIR = reciprocal

# Directory structure
BUILD_CORDIC_DIR = build_cordic
BUILD_RECIPROCAL_DIR = build_reciprocal
CORDIC_C_FILES_DIR = $(BUILD_CORDIC_DIR)/C_FILES
RECIPROCAL_C_FILES_DIR = $(BUILD_RECIPROCAL_DIR)/C_FILES

# Verilog directories
VERILOG_CORDIC_DIR = verilog_cordic
VERILOG_RECIPROCAL_DIR = verilog_reciprocal

# Target executables (in project directory)
CORDIC_TEST = cordic_test
RECIPROCAL_TEST = reciprocal_test

# Output files
CORDIC_OUTPUT = cordic_output.txt
RECIPROCAL_OUTPUT = reciprocal_output.txt

# BSC flags with increased function unfolding limits
BSC_SIM_FLAGS = -u -sim -no-warn-action-shadowing -steps-warn-interval 0 -steps 10000 -steps-max-intervals 10
BSC_VERILOG_FLAGS = -u -verilog -no-warn-action-shadowing -steps-warn-interval 0 -steps 10000 -steps-max-intervals 10
BSC_LINK_FLAGS = -sim -e

# Default target - builds tests, generates Verilog, then runs tests
.PHONY: all
all: $(RECIPROCAL_TEST) verilog-reciprocal $(CORDIC_TEST) verilog-cordic
	@echo "Running Reciprocal test..."
	./$(RECIPROCAL_TEST) | tee $(RECIPROCAL_OUTPUT)
	@echo ""
	@echo "Running CORDIC test..."
	./$(CORDIC_TEST) | tee $(CORDIC_OUTPUT)
	@echo ""
	@echo "Test outputs saved to:"
	@echo "  Reciprocal: $(RECIPROCAL_OUTPUT)"
	@echo "  CORDIC: $(CORDIC_OUTPUT)"
	@echo ""
	@echo "Verilog files generated in:"
	@echo "  Reciprocal: $(VERILOG_RECIPROCAL_DIR)/"
	@echo "  CORDIC: $(VERILOG_CORDIC_DIR)/"

# =============================================================================
# TESTING TARGETS
# =============================================================================

# CORDIC test target
.PHONY: test-cordic
test-cordic: $(CORDIC_TEST)
	@echo "Running CORDIC test..."
	./$(CORDIC_TEST) | tee $(CORDIC_OUTPUT)
	@echo "Output saved to $(CORDIC_OUTPUT)"

# Reciprocal test target
.PHONY: test-reciprocal
test-reciprocal: $(RECIPROCAL_TEST)
	@echo "Running Reciprocal test..."
	./$(RECIPROCAL_TEST) | tee $(RECIPROCAL_OUTPUT)
	@echo "Output saved to $(RECIPROCAL_OUTPUT)"

# Build CORDIC test executable
$(CORDIC_TEST): $(CORDIC_SRC_DIR)/test_cordic.bsv | $(BUILD_CORDIC_DIR) $(CORDIC_C_FILES_DIR)
	@echo "Compiling CORDIC testbench..."
	cd $(CORDIC_SRC_DIR) && $(BSC) $(BSC_SIM_FLAGS) -bdir ../$(BUILD_CORDIC_DIR) -simdir ../$(CORDIC_C_FILES_DIR) -g mkTestCORDIC test_cordic.bsv
	@echo "Linking CORDIC executable..."
	$(BSC) $(BSC_LINK_FLAGS) mkTestCORDIC -bdir $(BUILD_CORDIC_DIR) -simdir $(CORDIC_C_FILES_DIR) -o $(CORDIC_TEST)

# Build reciprocal test executable
$(RECIPROCAL_TEST): $(RECIPROCAL_SRC_DIR)/test_reciprocal.bsv | $(BUILD_RECIPROCAL_DIR) $(RECIPROCAL_C_FILES_DIR)
	@echo "Compiling reciprocal testbench..."
	cd $(RECIPROCAL_SRC_DIR) && $(BSC) $(BSC_SIM_FLAGS) -bdir ../$(BUILD_RECIPROCAL_DIR) -simdir ../$(RECIPROCAL_C_FILES_DIR) -g mkTestbench test_reciprocal.bsv
	@echo "Linking reciprocal executable..."
	$(BSC) $(BSC_LINK_FLAGS) mkTestbench -bdir $(BUILD_RECIPROCAL_DIR) -simdir $(RECIPROCAL_C_FILES_DIR) -o $(RECIPROCAL_TEST)

# =============================================================================
# VERILOG GENERATION TARGETS
# =============================================================================

# Generate all Verilog files
.PHONY: verilog
verilog: verilog-reciprocal verilog-cordic

# Generate CORDIC Verilog files
.PHONY: verilog-cordic
verilog-cordic: | $(BUILD_CORDIC_DIR) $(VERILOG_CORDIC_DIR)
	@echo "Generating CORDIC Verilog files..."
	@echo "Converting ROM.bsv to Verilog..."
	@cd $(CORDIC_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_CORDIC_DIR) -vdir ../$(VERILOG_CORDIC_DIR) -g mkROM ROM.bsv
	@echo "Converting GenericComparator.bsv to Verilog..."
	@cd $(CORDIC_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_CORDIC_DIR) -vdir ../$(VERILOG_CORDIC_DIR) -g mkGenericComparator GenericComparator.bsv
	@echo "Converting ThresholdChecker.bsv to Verilog..."
	@cd $(CORDIC_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_CORDIC_DIR) -vdir ../$(VERILOG_CORDIC_DIR) -g mkThresholdChecker ThresholdChecker.bsv
	@echo "Converting CORDIC.bsv to Verilog..."
	@cd $(CORDIC_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_CORDIC_DIR) -vdir ../$(VERILOG_CORDIC_DIR) -g mkCORDIC CORDIC.bsv
	@echo "Converting test_cordic.bsv to Verilog..."
	@cd $(CORDIC_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_CORDIC_DIR) -vdir ../$(VERILOG_CORDIC_DIR) -g mkTestCORDIC test_cordic.bsv
	@echo "All CORDIC Verilog files generated in $(VERILOG_CORDIC_DIR)/"

# Generate reciprocal Verilog files (with fallback for testbench)
.PHONY: verilog-reciprocal
verilog-reciprocal: | $(BUILD_RECIPROCAL_DIR) $(VERILOG_RECIPROCAL_DIR)
	@echo "Generating reciprocal Verilog files..."
	@echo "Converting FloatingPointExtractor.bsv to Verilog..."
	@cd $(RECIPROCAL_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_RECIPROCAL_DIR) -vdir ../$(VERILOG_RECIPROCAL_DIR) -g mkFloatingPointExtractor FloatingPointExtractor.bsv
	@echo "Converting TopLevelSystem.bsv to Verilog..."
	@cd $(RECIPROCAL_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_RECIPROCAL_DIR) -vdir ../$(VERILOG_RECIPROCAL_DIR) -g mkTopLevelSystem TopLevelSystem.bsv
	@echo "Converting test_reciprocal.bsv to Verilog (may fail due to scheduling conflicts)..."
	@cd $(RECIPROCAL_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_RECIPROCAL_DIR) -vdir ../$(VERILOG_RECIPROCAL_DIR) -g mkTestbench test_reciprocal.bsv || (echo "Warning: Testbench Verilog generation failed, but other modules succeeded" && true)
	@if [ ! -f $(VERILOG_RECIPROCAL_DIR)/mkTestbench.v ]; then \
		echo "Note: mkTestbench.v not generated due to scheduling conflicts"; \
	fi
	@echo "Reciprocal Verilog files generated in $(VERILOG_RECIPROCAL_DIR)/"

# Alternative: Generate only synthesis modules (no testbench)
.PHONY: verilog-reciprocal-synth
verilog-reciprocal-synth: | $(BUILD_RECIPROCAL_DIR) $(VERILOG_RECIPROCAL_DIR)
	@echo "Generating reciprocal synthesis Verilog files..."
	@echo "Converting FloatingPointExtractor.bsv to Verilog..."
	@cd $(RECIPROCAL_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_RECIPROCAL_DIR) -vdir ../$(VERILOG_RECIPROCAL_DIR) -g mkFloatingPointExtractor FloatingPointExtractor.bsv
	@echo "Converting TopLevelSystem.bsv to Verilog..."
	@cd $(RECIPROCAL_SRC_DIR) && $(BSC) $(BSC_VERILOG_FLAGS) -bdir ../$(BUILD_RECIPROCAL_DIR) -vdir ../$(VERILOG_RECIPROCAL_DIR) -g mkTopLevelSystem TopLevelSystem.bsv
	@echo "Skipping testbench (synthesis modules only)"
	@echo "Synthesis Verilog files generated in $(VERILOG_RECIPROCAL_DIR)/"

# =============================================================================
# DIRECTORY CREATION TARGETS
# =============================================================================

$(BUILD_CORDIC_DIR):
	@echo "Creating CORDIC build directory..."
	@mkdir -p $@

$(BUILD_RECIPROCAL_DIR):
	@echo "Creating reciprocal build directory..."
	@mkdir -p $@

$(CORDIC_C_FILES_DIR): | $(BUILD_CORDIC_DIR)
	@echo "Creating CORDIC C files directory..."
	@mkdir -p $@

$(RECIPROCAL_C_FILES_DIR): | $(BUILD_RECIPROCAL_DIR)
	@echo "Creating reciprocal C files directory..."
	@mkdir -p $@

$(VERILOG_CORDIC_DIR):
	@echo "Creating CORDIC Verilog directory..."
	@mkdir -p $@

$(VERILOG_RECIPROCAL_DIR):
	@echo "Creating reciprocal Verilog directory..."
	@mkdir -p $@

# =============================================================================
# CLEANING TARGETS
# =============================================================================

.PHONY: clean
clean:
	@echo "Cleaning all build artifacts..."
	@$(RM) $(BUILD_CORDIC_DIR) $(BUILD_RECIPROCAL_DIR)
	@$(RM) $(CORDIC_TEST) $(RECIPROCAL_TEST)
	@$(RM) $(CORDIC_OUTPUT) $(RECIPROCAL_OUTPUT)
	@$(RM) $(VERILOG_CORDIC_DIR) $(VERILOG_RECIPROCAL_DIR)
	@$(RM) *.bo *.ba *.so *.cxx *.h *.o
	@echo "Done"

.PHONY: clean-cordic
clean-cordic:
	@echo "Cleaning CORDIC build artifacts..."
	@$(RM) $(BUILD_CORDIC_DIR)
	@$(RM) $(CORDIC_TEST)
	@$(RM) $(CORDIC_OUTPUT)
	@$(RM) mkTestCORDIC.so
	@echo "Done"

.PHONY: clean-reciprocal
clean-reciprocal:
	@echo "Cleaning reciprocal build artifacts..."
	@$(RM) $(BUILD_RECIPROCAL_DIR)
	@$(RM) $(RECIPROCAL_TEST)
	@$(RM) $(RECIPROCAL_OUTPUT)
	@$(RM) mkTestbench.so
	@echo "Done"

.PHONY: clean-verilog-cordic
clean-verilog-cordic:
	@echo "Cleaning CORDIC Verilog files..."
	@$(RM) $(VERILOG_CORDIC_DIR)
	@echo "Done"

.PHONY: clean-verilog-reciprocal
clean-verilog-reciprocal:
	@echo "Cleaning reciprocal Verilog files..."
	@$(RM) $(VERILOG_RECIPROCAL_DIR)
	@echo "Done"

.PHONY: clean-outputs
clean-outputs:
	@echo "Cleaning output files..."
	@$(RM) $(CORDIC_OUTPUT) $(RECIPROCAL_OUTPUT)
	@echo "Done"

# =============================================================================
# UTILITY TARGETS
# =============================================================================

.PHONY: help
help:
	@echo "Reciprocal and CORDIC Compute Makefile"
	@echo "======================================"
	@echo ""
	@echo "Test Targets:"
	@echo "  all                     - Build tests, generate Verilog, and run both tests"
	@echo "  test-cordic             - Build and run CORDIC test only"
	@echo "  test-reciprocal         - Build and run reciprocal test only"
	@echo ""
	@echo "Verilog Generation:"
	@echo "  verilog                 - Generate all Verilog files"
	@echo "  verilog-cordic          - Generate CORDIC Verilog files only"
	@echo "  verilog-reciprocal      - Generate reciprocal Verilog files (with testbench)"
	@echo "  verilog-reciprocal-synth - Generate reciprocal synthesis files only"
	@echo ""
	@echo "Cleaning:"
	@echo "  clean                   - Clean all build artifacts and outputs"
	@echo "  clean-cordic            - Clean CORDIC artifacts only"
	@echo "  clean-reciprocal        - Clean reciprocal artifacts only"
	@echo "  clean-verilog-cordic    - Clean CORDIC Verilog files only"
	@echo "  clean-verilog-reciprocal - Clean reciprocal Verilog files only"
	@echo "  clean-outputs           - Clean output text files only"
	@echo "  help                    - Show this help"
	@echo ""
	@echo "Directory Structure:"
	@echo "  $(CORDIC_SRC_DIR)/        - CORDIC source files"
	@echo "  $(RECIPROCAL_SRC_DIR)/    - Reciprocal source files"
	@echo "  $(BUILD_CORDIC_DIR)/          - CORDIC build artifacts"
	@echo "  $(CORDIC_C_FILES_DIR)/     - CORDIC C++ files"
	@echo "  $(BUILD_RECIPROCAL_DIR)/      - Reciprocal build artifacts"
	@echo "  $(RECIPROCAL_C_FILES_DIR)/ - Reciprocal C++ files"
	@echo "  $(VERILOG_CORDIC_DIR)/     - CORDIC Verilog files"
	@echo "  $(VERILOG_RECIPROCAL_DIR)/ - Reciprocal Verilog files"

# Make sure intermediate files are not deleted
.PRECIOUS: %.bo %.ba %.v

# Phony targets
.PHONY: all test-cordic test-reciprocal verilog verilog-cordic verilog-reciprocal verilog-reciprocal-synth
.PHONY: clean clean-cordic clean-reciprocal clean-verilog-cordic clean-verilog-reciprocal
.PHONY: clean-outputs help