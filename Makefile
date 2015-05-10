all: NumLinkSolver

NumLinkSolver: NumLinkSolver.o Utils.o
	cc -o $@ $^
