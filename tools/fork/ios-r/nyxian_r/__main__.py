# Fork doctoralvarez/Nyxian — version 0.1.0
# Changelog:
#  - 0.1.0 (2026-11-19): python3 -m nyxian_r            R console
#                        python3 -m nyxian_r FILE.R ARGS (like Rscript)
#                        python3 -m nyxian_r -e 'CODE'   (like Rscript -e)
import sys

import nyxian_r


def main(argv):
    args = [a for a in argv if a not in ("--vanilla", "--no-save", "--quiet", "-q", "--slave", "--no-echo")]
    if args[:1] == ["-e"] and len(args) > 1:
        nyxian_r.start()
        return 0 if nyxian_r.evaluate(args[1]) == "ok" else 1
    if args and not args[0].startswith("-"):
        return nyxian_r.run_file(args[0], args[1:])
    return nyxian_r.console()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
