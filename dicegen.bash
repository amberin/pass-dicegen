#! /usr/bin/env bash

local opts qrcode= clip=0 force=0 length=0 inplace=0 pass
opts="$($GETOPT -o qcifl: -l qrcode,clip,in-place,force,length: -n "$PROGRAM" -- "$@")"
local err=$?
eval set -- "$opts"
while true; do case $1 in
  -l|--length) shift; length=$1; shift ;;
  -q|--qrcode) qrcode=1; shift ;;
	-c|--clip) clip=1; shift ;;
	-f|--force) force=1; shift ;;
	-i|--in-place) inplace=1; shift ;;
	--) shift; break ;;
esac done

[[ $err -ne 0 || $# -ne 1 || ( $force -eq 1 && $inplace -eq 1 ) || ( $qrcode -eq 1 && $clip -eq 1 ) ]] && die "Usage: $PROGRAM $COMMAND [--length,-l length-in-bits] [--clip,-c] [--qrcode,-q] [--in-place,-i | --force,-f]"
local path="$1"
check_sneaky_paths "$path"
mkdir -p -v "$PREFIX/$(dirname -- "$path")"
set_gpg_recipients "$(dirname -- "$path")"
local passfile="$PREFIX/$path.gpg"
set_git "$passfile"

[[ $inplace -eq 0 && $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

if [[ $length -gt 23 && $length -lt 86 ]]; then
  pass=$(pwqgen random=$length) || die "Password generation using pwqgen failed."
else
  pass=$(pwqgen random=65) || die "Password generation using pwqgen failed."
fi

if [[ $inplace -eq 0 ]]; then
	echo "$pass" | $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" || die "Password encryption aborted."
else
	local passfile_temp="${passfile}.tmp.${RANDOM}.${RANDOM}.${RANDOM}.${RANDOM}.--"
	if { echo "$pass"; $GPG -d "${GPG_OPTS[@]}" "$passfile" | tail -n +2; } | $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile_temp" "${GPG_OPTS[@]}"; then
		mv "$passfile_temp" "$passfile"
	else
		rm -f "$passfile_temp"
		die "Could not reencrypt new password."
	fi
fi
local verb="Add"
[[ $inplace -eq 1 ]] && verb="Replace"
git_add_file "$passfile" "$verb generated password for ${path}."

if [[ $clip -eq 1 ]]; then
	clip "$pass" "$path"
elif [[ $qrcode -eq 1 ]]; then
	qrcode "$pass" "$path"
else
	printf "\e[1mThe generated password for \e[4m%s\e[24m is:\e[0m\n\e[1m\e[93m%s\e[0m\n" "$path" "$pass"
fi
