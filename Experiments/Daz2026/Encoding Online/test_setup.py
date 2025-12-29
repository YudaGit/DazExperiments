#!/usr/bin/env python
"""
Test script to verify the experiment setup is correct.
Run this before starting the Flask server.
"""

import sys
import os

def test_imports():
    """Test if all required modules can be imported"""
    print("Testing imports...")
    try:
        import flask
        print("  [OK] Flask")
    except ImportError as e:
        print(f"  ✗ Flask: {e}")
        return False
    
    try:
        import config
        print("  [OK] config")
    except ImportError as e:
        print(f"  [FAIL] config: {e}")
        return False
    
    try:
        import expt_config
        print("  [OK] expt_config")
    except ImportError as e:
        print(f"  [FAIL] expt_config: {e}")
        return False
    
    try:
        import MallExperiment
        print("  [OK] MallExperiment")
    except ImportError as e:
        print(f"  [FAIL] MallExperiment: {e}")
        return False
    
    try:
        import SimpleDB
        print("  [OK] SimpleDB")
    except ImportError as e:
        print(f"  [FAIL] SimpleDB: {e}")
        return False
    
    try:
        import user_utils
        print("  [OK] user_utils")
    except ImportError as e:
        print(f"  [FAIL] user_utils: {e}")
        return False
    
    return True

def test_config():
    """Test if config has required variables"""
    print("\nTesting config...")
    try:
        import config
        required = ['EXPT_UID', 'DEBUG', 'RESULTS_DIR']
        for var in required:
            if hasattr(config, var):
                print(f"  [OK] {var} = {getattr(config, var)}")
            else:
                print(f"  [FAIL] Missing: {var}")
                return False
        return True
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False

def test_expt_config():
    """Test if expt_config has required function"""
    print("\nTesting expt_config...")
    try:
        import expt_config
        if hasattr(expt_config, 'get_data'):
            print("  [OK] get_data function exists")
            # Test calling it
            try:
                result = expt_config.get_data({})
                print(f"  [OK] get_data() returns: {type(result)}")
                if isinstance(result, dict):
                    print(f"    Keys: {list(result.keys())}")
                return True
            except Exception as e:
                print(f"  [FAIL] Error calling get_data(): {e}")
                return False
        else:
            print("  [FAIL] Missing: get_data function")
            return False
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return False

def test_static_folder():
    """Test if static folder exists"""
    print("\nTesting static folder...")
    import config
    static_folder = f"static_{config.EXPT_UID}"
    if os.path.isdir(static_folder):
        print(f"  [OK] Static folder exists: {static_folder}")
        return True
    elif os.path.isdir('static'):
        print(f"  [OK] Using fallback static folder: static")
        return True
    else:
        print(f"  [FAIL] Static folder not found: {static_folder}")
        return False

def test_templates():
    """Test if required templates exist"""
    print("\nTesting templates...")
    required_templates = ['exp.html', 'experiment_wrapper.html']
    for template in required_templates:
        path = os.path.join('templates', template)
        if os.path.isfile(path):
            print(f"  [OK] {template}")
        else:
            print(f"  [FAIL] Missing: {template}")
            return False
    return True

def test_stimulus_file():
    """Test if stimulus file exists"""
    print("\nTesting stimulus files...")
    try:
        import expt_config
        if hasattr(expt_config, 'stimulus_file'):
            stimulus_file = expt_config.stimulus_file
            if os.path.isfile(stimulus_file):
                print(f"  [OK] Stimulus file exists: {stimulus_file}")
                return True
            else:
                print(f"  [WARN] Stimulus file not found: {stimulus_file} (may be loaded from S3)")
                return True  # Not critical if loading from S3
        else:
            print("  [WARN] No stimulus_file defined (may not be needed)")
            return True
    except Exception as e:
        print(f"  [WARN] Could not check stimulus file: {e}")
        return True

def main():
    print("=" * 60)
    print("Experiment Setup Test")
    print("=" * 60)
    
    all_passed = True
    all_passed &= test_imports()
    all_passed &= test_config()
    all_passed &= test_expt_config()
    all_passed &= test_static_folder()
    all_passed &= test_templates()
    all_passed &= test_stimulus_file()
    
    print("\n" + "=" * 60)
    if all_passed:
        print("[SUCCESS] All tests passed! You should be able to run the server.")
        print("\nTo start the server, run:")
        print("  python experiment.py")
        print("  or")
        print("  flask run")
        print("\nThen visit: http://localhost:5000/unique-expt")
    else:
        print("[FAIL] Some tests failed. Please fix the issues above.")
        sys.exit(1)
    print("=" * 60)

if __name__ == '__main__':
    main()

