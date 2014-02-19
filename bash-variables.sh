$$	Process ID (PID) of the script itself.
$#	Number of arguments passed to this process
$0	Full path to currently-running executable
$1	First argument passed to this process
$2	Second argument passed to this process, etc for $3...
$_	Final argument passed to previous command
$*	An eval'd string of all my arguments.  You probably wanted $@.
$@	A quoted string, not eval'd, of all my arguments
$-	Flags passed to this script.  In "echo -n blah", it would be "-n".
$!	PID of last job running in background.
$?	Exit status of most recently-completed child process
