def main():
    from . import run_checks
    out = run_checks(verbose=True)
    # non-zero exit if torch is missing
    if not out["torch"]["ok"]:
        raise SystemExit(1)
    # don’t force CUDA to be True—some machines may be CPU-only
    # (uncomment to require CUDA)
    if not out["cuda"]["ok"]:
        raise SystemExit(2)

if __name__ == "__main__":
    main()
