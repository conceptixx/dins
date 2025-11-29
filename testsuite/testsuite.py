#!/usr/bin/env python3
"""
DINS Test Suite - Main Test Runner
Location: <DINS_ROOT>/testsuite/testsuite.py

This is the main entry point for the DINS test suite. It provides:
- Automatic discovery of test modules (module_* directories)
- Sequential or selective module execution
- Configurable failure behavior (stop-on-fail vs continue)
- Logging with timestamps and module names
- Human-readable output with pass/fail summaries
- Pre-deployment validation mode

Usage:
    python testsuite.py                    # Run all modules
    python testsuite.py --module core      # Run specific module
    python testsuite.py --continue-on-fail # Don't stop on failures
    python testsuite.py --pre-deployment   # Pre-deployment validation
    python testsuite.py --list             # List available modules
    python testsuite.py --verbose          # Verbose output
"""

import argparse
import importlib.util
import json
import logging
import os
import sys
import traceback
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple


# =============================================================================
# CONSTANTS
# =============================================================================

TESTSUITE_DIR = Path(__file__).parent.resolve()
DINS_ROOT = TESTSUITE_DIR.parent
LOGS_DIR = TESTSUITE_DIR / "logs"
MODULE_PREFIX = "module_"

# ANSI colors for terminal output
class Colors:
    """ANSI color codes for terminal output"""
    RESET = "\033[0m"
    BOLD = "\033[1m"
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    
    @classmethod
    def disable(cls):
        """Disable colors (for non-TTY output)"""
        cls.RESET = cls.BOLD = cls.RED = cls.GREEN = ""
        cls.YELLOW = cls.BLUE = cls.CYAN = ""


# Disable colors if not a TTY
if not sys.stdout.isatty():
    Colors.disable()


# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class TestResult:
    """Result of a single test"""
    name: str
    passed: bool
    duration_ms: float
    error: Optional[str] = None
    
    def __str__(self) -> str:
        status = f"{Colors.GREEN}PASS{Colors.RESET}" if self.passed else f"{Colors.RED}FAIL{Colors.RESET}"
        result = f"  [{status}] {self.name} ({self.duration_ms:.1f}ms)"
        if self.error:
            result += f"\n         Error: {self.error}"
        return result


@dataclass
class ModuleResult:
    """Result of a test module execution"""
    name: str
    tests_run: int = 0
    tests_passed: int = 0
    tests_failed: int = 0
    test_results: List[TestResult] = field(default_factory=list)
    duration_ms: float = 0.0
    error: Optional[str] = None
    skipped: bool = False
    
    @property
    def passed(self) -> bool:
        """Module passes if all tests pass and no critical error"""
        return self.tests_failed == 0 and self.error is None and not self.skipped
    
    def add_result(self, result: TestResult) -> None:
        """Add a test result to this module"""
        self.test_results.append(result)
        self.tests_run += 1
        if result.passed:
            self.tests_passed += 1
        else:
            self.tests_failed += 1


@dataclass
class SuiteResult:
    """Result of the entire test suite"""
    modules_run: int = 0
    modules_passed: int = 0
    modules_failed: int = 0
    modules_skipped: int = 0
    module_results: List[ModuleResult] = field(default_factory=list)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    
    @property
    def passed(self) -> bool:
        """Suite passes if all modules pass"""
        return self.modules_failed == 0
    
    @property
    def duration_s(self) -> float:
        """Duration in seconds"""
        if self.start_time and self.end_time:
            return (self.end_time - self.start_time).total_seconds()
        return 0.0
    
    def add_result(self, result: ModuleResult) -> None:
        """Add a module result"""
        self.module_results.append(result)
        self.modules_run += 1
        if result.skipped:
            self.modules_skipped += 1
        elif result.passed:
            self.modules_passed += 1
        else:
            self.modules_failed += 1


# =============================================================================
# LOGGING SETUP
# =============================================================================

def setup_logging(verbose: bool = False) -> logging.Logger:
    """Setup logging for the test suite"""
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = LOGS_DIR / f"testsuite_{timestamp}.log"
    
    # Create logger
    logger = logging.getLogger("dins.testsuite")
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)
    
    # File handler - always verbose
    file_handler = logging.FileHandler(log_file)
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    ))
    
    # Console handler - based on verbose flag
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.DEBUG if verbose else logging.WARNING)
    console_handler.setFormatter(logging.Formatter('%(message)s'))
    
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    logger.info(f"Log file: {log_file}")
    return logger


# =============================================================================
# MODULE DISCOVERY
# =============================================================================

def discover_modules() -> List[Path]:
    """
    Discover all test modules in the testsuite directory.
    
    Modules are directories matching the pattern 'module_*'.
    Returns a sorted list of module directories.
    """
    modules = []
    
    for item in TESTSUITE_DIR.iterdir():
        if item.is_dir() and item.name.startswith(MODULE_PREFIX):
            # Check for main test file
            module_name = item.name
            test_file = item / f"test_{module_name}.py"
            
            if test_file.exists():
                modules.append(item)
    
    # Sort lexicographically for deterministic order
    modules.sort(key=lambda p: p.name)
    return modules


def get_module_info(module_path: Path) -> Dict[str, Any]:
    """Get information about a test module"""
    module_name = module_path.name
    readme = module_path / "README.md"
    
    info = {
        "name": module_name,
        "path": str(module_path),
        "test_file": str(module_path / f"test_{module_name}.py"),
        "has_readme": readme.exists(),
        "description": ""
    }
    
    # Try to extract description from README
    if readme.exists():
        try:
            content = readme.read_text()
            # Get first non-empty line after any heading
            for line in content.split('\n'):
                line = line.strip()
                if line and not line.startswith('#'):
                    info["description"] = line[:100]
                    break
        except Exception:
            pass
    
    return info


# =============================================================================
# MODULE EXECUTION
# =============================================================================

def load_module_tests(module_path: Path, logger: logging.Logger) -> Optional[Callable]:
    """
    Dynamically load the run_tests function from a module.
    
    Each module must have a test_module_<name>.py file with a run_tests() function
    that returns a ModuleResult.
    """
    module_name = module_path.name
    test_file = module_path / f"test_{module_name}.py"
    
    if not test_file.exists():
        logger.error(f"Test file not found: {test_file}")
        return None
    
    try:
        # Load the module dynamically
        spec = importlib.util.spec_from_file_location(
            f"testsuite.{module_name}",
            test_file
        )
        module = importlib.util.module_from_spec(spec)
        
        # Add testsuite directory to path for imports
        if str(TESTSUITE_DIR) not in sys.path:
            sys.path.insert(0, str(TESTSUITE_DIR))
        
        spec.loader.exec_module(module)
        
        # Get the run_tests function
        if not hasattr(module, 'run_tests'):
            logger.error(f"Module {module_name} has no run_tests() function")
            return None
        
        return module.run_tests
        
    except Exception as e:
        logger.error(f"Failed to load module {module_name}: {e}")
        logger.debug(traceback.format_exc())
        return None


def run_module(
    module_path: Path,
    logger: logging.Logger,
    config: Dict[str, Any]
) -> ModuleResult:
    """
    Run all tests in a module.
    
    Returns a ModuleResult with pass/fail status and details.
    """
    module_name = module_path.name
    result = ModuleResult(name=module_name)
    
    logger.info(f"Running module: {module_name}")
    start_time = datetime.now()
    
    try:
        # Load the test function
        run_tests = load_module_tests(module_path, logger)
        
        if run_tests is None:
            result.error = "Failed to load module tests"
            result.skipped = True
            return result
        
        # Run the tests
        # The run_tests function should return a ModuleResult
        test_result = run_tests(config)
        
        if isinstance(test_result, ModuleResult):
            result = test_result
            result.name = module_name
        else:
            # Handle legacy format where run_tests returns (passed, tests_run, tests_passed, tests_failed)
            if isinstance(test_result, tuple) and len(test_result) >= 4:
                passed, tests_run, tests_passed, tests_failed = test_result[:4]
                result.tests_run = tests_run
                result.tests_passed = tests_passed
                result.tests_failed = tests_failed
            else:
                result.error = "Invalid return value from run_tests()"
                
    except Exception as e:
        result.error = str(e)
        logger.error(f"Module {module_name} failed with error: {e}")
        logger.debug(traceback.format_exc())
    
    end_time = datetime.now()
    result.duration_ms = (end_time - start_time).total_seconds() * 1000
    
    return result


# =============================================================================
# OUTPUT FORMATTING
# =============================================================================

def print_banner(text: str, char: str = "=") -> None:
    """Print a banner with surrounding decoration"""
    width = max(60, len(text) + 4)
    print(f"\n{Colors.BOLD}{char * width}")
    print(f" {text}")
    print(f"{char * width}{Colors.RESET}")


def print_module_banner(module_name: str) -> None:
    """Print a module start banner"""
    print(f"\n{Colors.CYAN}{'─' * 60}")
    print(f" 🧪 Module: {module_name}")
    print(f"{'─' * 60}{Colors.RESET}")


def print_module_result(result: ModuleResult) -> None:
    """Print the result of a module execution"""
    if result.skipped:
        status = f"{Colors.YELLOW}SKIPPED{Colors.RESET}"
    elif result.passed:
        status = f"{Colors.GREEN}PASS{Colors.RESET}"
    else:
        status = f"{Colors.RED}FAIL{Colors.RESET}"
    
    print(f"\n{Colors.BOLD}Module Result: [{status}]{Colors.RESET}")
    print(f"  Tests: {result.tests_run} total, "
          f"{result.tests_passed} passed, {result.tests_failed} failed")
    print(f"  Duration: {result.duration_ms:.1f}ms")
    
    if result.error:
        print(f"  {Colors.RED}Error: {result.error}{Colors.RESET}")
    
    # Print individual test results if there were failures
    if result.tests_failed > 0:
        print(f"\n  {Colors.YELLOW}Failed tests:{Colors.RESET}")
        for test in result.test_results:
            if not test.passed:
                print(f"    • {test.name}: {test.error}")


def print_summary(result: SuiteResult) -> None:
    """Print the final test suite summary"""
    print_banner("TEST SUITE SUMMARY")
    
    # Overall status
    if result.passed:
        status = f"{Colors.GREEN}✅ ALL TESTS PASSED{Colors.RESET}"
    else:
        status = f"{Colors.RED}❌ TESTS FAILED{Colors.RESET}"
    
    print(f"\n{Colors.BOLD}{status}{Colors.RESET}")
    print(f"\nModules: {result.modules_run} total")
    print(f"  • {Colors.GREEN}Passed: {result.modules_passed}{Colors.RESET}")
    print(f"  • {Colors.RED}Failed: {result.modules_failed}{Colors.RESET}")
    if result.modules_skipped > 0:
        print(f"  • {Colors.YELLOW}Skipped: {result.modules_skipped}{Colors.RESET}")
    
    print(f"\nTotal duration: {result.duration_s:.2f}s")
    
    # List failed modules
    if result.modules_failed > 0:
        print(f"\n{Colors.RED}Failed modules:{Colors.RESET}")
        for mod in result.module_results:
            if not mod.passed and not mod.skipped:
                print(f"  • {mod.name}")
    
    print()


# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

def run_testsuite(
    modules: Optional[List[str]] = None,
    continue_on_fail: bool = False,
    pre_deployment: bool = False,
    verbose: bool = False
) -> SuiteResult:
    """
    Run the DINS test suite.
    
    Args:
        modules: List of specific modules to run (None = all)
        continue_on_fail: Continue running after module failures
        pre_deployment: Run in pre-deployment mode (critical modules only)
        verbose: Enable verbose output
    
    Returns:
        SuiteResult with pass/fail status and details
    """
    logger = setup_logging(verbose)
    result = SuiteResult()
    result.start_time = datetime.now()
    
    print_banner("DINS TEST SUITE", "═")
    print(f"Started: {result.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"DINS Root: {DINS_ROOT}")
    
    # Configuration for tests
    config = {
        "dins_root": str(DINS_ROOT),
        "testsuite_dir": str(TESTSUITE_DIR),
        "pre_deployment": pre_deployment,
        "verbose": verbose
    }
    
    # Discover modules
    all_modules = discover_modules()
    
    if not all_modules:
        print(f"\n{Colors.YELLOW}No test modules found!{Colors.RESET}")
        result.end_time = datetime.now()
        return result
    
    # Filter modules if specific ones requested
    if modules:
        module_filter = set()
        for m in modules:
            # Allow 'core' or 'module_core' syntax
            if not m.startswith(MODULE_PREFIX):
                m = MODULE_PREFIX + m
            module_filter.add(m)
        
        all_modules = [m for m in all_modules if m.name in module_filter]
        
        if not all_modules:
            print(f"\n{Colors.YELLOW}No matching modules found!{Colors.RESET}")
            result.end_time = datetime.now()
            return result
    
    # Pre-deployment mode: prioritize core modules
    if pre_deployment:
        # In pre-deployment mode, module_core must pass first
        core_modules = [m for m in all_modules if 'core' in m.name.lower()]
        other_modules = [m for m in all_modules if 'core' not in m.name.lower()]
        all_modules = core_modules + other_modules
        continue_on_fail = False  # Stop on first failure in pre-deployment
    
    print(f"\nModules to run: {len(all_modules)}")
    for m in all_modules:
        info = get_module_info(m)
        print(f"  • {m.name}: {info['description'] or 'No description'}")
    
    # Run each module
    for module_path in all_modules:
        print_module_banner(module_path.name)
        
        module_result = run_module(module_path, logger, config)
        result.add_result(module_result)
        
        print_module_result(module_result)
        
        # Check if we should stop on failure
        if not module_result.passed and not continue_on_fail:
            if pre_deployment:
                print(f"\n{Colors.RED}Pre-deployment check failed! Stopping.{Colors.RESET}")
            break
    
    result.end_time = datetime.now()
    print_summary(result)
    
    return result


def list_modules() -> None:
    """List all available test modules"""
    print_banner("AVAILABLE TEST MODULES")
    
    modules = discover_modules()
    
    if not modules:
        print(f"\n{Colors.YELLOW}No test modules found!{Colors.RESET}")
        return
    
    for module_path in modules:
        info = get_module_info(module_path)
        print(f"\n{Colors.BOLD}{info['name']}{Colors.RESET}")
        print(f"  Path: {info['path']}")
        print(f"  Test file: {info['test_file']}")
        if info['description']:
            print(f"  Description: {info['description']}")
        print(f"  Has README: {'Yes' if info['has_readme'] else 'No'}")


# =============================================================================
# CLI ENTRY POINT
# =============================================================================

def main():
    """Main entry point for CLI"""
    parser = argparse.ArgumentParser(
        description="DINS Test Suite Runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python testsuite.py                      Run all test modules
  python testsuite.py --module core        Run only module_core
  python testsuite.py --module core webui  Run core and webui modules
  python testsuite.py --continue-on-fail   Don't stop on failures
  python testsuite.py --pre-deployment     Pre-deployment validation
  python testsuite.py --list               List available modules
"""
    )
    
    parser.add_argument(
        '--module', '-m',
        nargs='+',
        help='Run specific module(s) only'
    )
    
    parser.add_argument(
        '--continue-on-fail', '-c',
        action='store_true',
        help='Continue running after module failures'
    )
    
    parser.add_argument(
        '--pre-deployment', '-p',
        action='store_true',
        help='Run in pre-deployment validation mode'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Enable verbose output'
    )
    
    parser.add_argument(
        '--list', '-l',
        action='store_true',
        dest='list_modules',
        help='List available test modules'
    )
    
    args = parser.parse_args()
    
    if args.list_modules:
        list_modules()
        sys.exit(0)
    
    result = run_testsuite(
        modules=args.module,
        continue_on_fail=args.continue_on_fail,
        pre_deployment=args.pre_deployment,
        verbose=args.verbose
    )
    
    # Exit with appropriate code
    sys.exit(0 if result.passed else 1)


if __name__ == "__main__":
    main()
