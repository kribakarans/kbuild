#!/bin/bash

set -u

VERSION=1.0

FMTNC='\e[0m'
FMTBRED='\e[1;31m'
FMTBGRN='\e[1;32m'
FMTBYLW='\e[1;33m'
FMTBBLUE='\e[1;34m'

GPVAL=0
CHILD_PID=0
LOOKUP_RANGE=5
CHECKPOINT_FILE="kbuild-checkpoints.in"

STDOUT_LOG=build.log
STDERR_LOG=builderr.log
DEBUG_FILE=/tmp/kbuild.log
PROGRESS_FILE=/tmp/kbuild-progress.log

execv() {
	set -v
	eval $@
	EVAL=$?
	set +v

	return $EVAL
}

echo_info() {
	echo -e "${FMTBYLW}$@${FMTNC}"
}

echo_error() {
	echo -e "${FMTBRED}$@${FMTNC}"
}

print_debug() {
	echo -e "$@" >> $DEBUG_FILE
}

kbuild_echo() {
	echo -e "\033[K\r$@"
}

kbuild_signal_handler() {
	pkill -INT -P $CHILD_PID
	kill  -INT    $CHILD_PID

	print_debug "\nBuild terminated.\n"
	kbuild_exit
}

kbuild_exit() {
	tput cnorm      # Enable cursor
	wait $CHILD_PID 2>/dev/null # Wait for child process to exit
	CHILD_RETVAL=$?

	MSG="Builder exited with $CHILD_RETVAL."

	kbuild_echo $MSG
	print_debug $MSG
	print_debug "======================================================================\n"

	exit $CHILD_RETVAL
}

kbuild_print_progress() {
	local PERCENTAGE=$1
	local MAX_WIDTH=$((LINE_WIDTH / 2))
	local FRACTION=$(( $1 * $MAX_WIDTH / $2 ))
	local BAR=$(printf "%0.s█" $(seq 1 $FRACTION))
	local SPACES=$(printf "%0.s " $(seq $((MAX_WIDTH - FRACTION))))
	#local PERCENTAGE=$((100 * FRACTION / MAX_WIDTH)) # NOTE: Don't re-calculate @PERCENTAGE again

	if [ $PERCENTAGE -ge 100 ]; then
		printf "\e[K%-s (%d%%)\n" "${BAR}${SPACES}" ${PERCENTAGE}
	else
		printf "\e[K%-s (%d%%)\r" "${BAR}${SPACES}" ${PERCENTAGE}
	fi
}

kbuild_refresh_progress() {
	local PROGVAL=$1
	local PROGMAX=100

	kbuild_print_progress $PROGVAL $PROGMAX

	if [ $PROGVAL -ge 100 ]; then
		kbuild_exit
	fi
}

kbuild_progress_worker() {
	local PVAL=0
	local DELAY=0
	local LINE_WIDTH=150
	local LINE_ITERATION=0
	local LINE_HEIGHT=$LOOKUP_RANGE

	while true; do
		print_debug "\n----------------------------- LOOKUP ${LINE_ITERATION} -------------------------------"

		# Break if child not exist
		if ! ps -p $CHILD_PID &>/dev/null; then
			echo ""
			break
		fi

		# Commented: for smooth progess
		# Continue loop if minimal logs
		NLINES=$(tail -n $LINE_HEIGHT $STDOUT_LOG | wc -l)
		#if [ $NLINES -lt $LINE_HEIGHT ]; then
		#	print_debug "Minimal logs: $NLINES (-le $LINE_HEIGHT)"
		#	((LINE_ITERATION++))
		#	sleep $DELAY
		#	continue
		#fi

		# -------------------- TRAVERSE BUILD LOG START --------------------
		# Reverse lookup build logs with Tac command
		tail -n $LINE_HEIGHT $STDOUT_LOG | tac | while read -r LINE; do
			TEXT="${LINE:0:$LINE_WIDTH}" # Truncate @LINE length to @LINE_WIDTH
			print_debug "#### $TEXT"
			# -------------------- LOOKUP START --------------------
			# Reverse lookup kbuild checkpoints and return build percentage
			while IFS= read -r LINE; do
				# Extract percentage and string from the line using awk
				CHECKPOINT=$(echo "${LINE}" | awk -F '|' '{print $2}')

				if [ -z "$CHECKPOINT" ]; then
					continue
				fi

				#print_debug "  == $CHECKPOINT"
				if [[ "$TEXT" =~ "$CHECKPOINT" ]]; then
					PVAL=$(echo "${LINE}" | awk -F '|' '{print $1}')
					echo -e "  == ${FMTBGRN}${PVAL}${FMTBYLW} :: ${FMTBGRN}${CHECKPOINT}${FMTNC}" >> $PROGRESS_FILE
					print_debug "  == ${FMTBGRN}${PVAL}${FMTBYLW} :: ${FMTBGRN}${CHECKPOINT}${FMTNC}"
					kbuild_refresh_progress $PVAL
					break 2
				fi

				#sleep 0.001
			done < <(tac "$CHECKPOINT_FILE")
			#done < "$CHECKPOINT_FILE"
			# ---------------------- LOOKUP END --------------------
			#sleep 0.01
		done
		# -------------------- TRAVERSE BUILD LOG END --------------------

		print_debug "----------------------------------------------------------------------\n"
		((LINE_ITERATION++))
		sleep $DELAY
	done
}

kbuild_main() {
	if [ $# -lt 1 ]; then
		echo "Oops! missing file operand."
		echo "Try 'kbuild <program>'"
		exit 1
	fi

	if [ ! -f $CHECKPOINT_FILE ]; then
		echo "Oops! '$CHECKPOINT_FILE' is not exist."
		exit 1
	fi

	# Trap Signals
	trap kbuild_signal_handler TERM INT
	tput civis # Hide cursor
	truncate -s 0 $DEBUG_FILE

	# Execute Build
	print_debug "============================ KBuild Running =========================="

	echo -e "${FMTBBLUE}KBuild: ${FMTBYLW}$@${FMTNC}"
	$@ 2> $STDERR_LOG 1> $STDOUT_LOG 2>&1 &
	CHILD_PID=$! # Save child PID
	echo "Builder instance: $CHILD_PID"

	print_debug "Running client [$CHILD_PID] '$@'."
}

# Main:
kbuild_main $@

kbuild_progress_worker

kbuild_exit

# EOF
