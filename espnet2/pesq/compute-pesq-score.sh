#!/bin/bash

set -e
#set -u
set -o pipefail

log() {
    local fname=${BASH_SOURCE[1]##*/}
    echo -e "$(date '+%Y-%m-%dT%H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}

get_audio_in_ref_channel() {
    local audio_path=$1
    local ref_channel=$2
    local output_path=$3
    local relative_to=$4
    local nostrict=$5

    if [ -z "$relative_to" ]; then
        relative_to=""
    else
        relative_to="--relative-to=$relative_to"
    fi

    channels=$(soxi -c "$audio_path")
    if [ -z "$channels" ]; then
        >&2 echo "ERROR: fail to get audio channels in '$audio_path'"
        exit 1
    elif [ $ref_channel -gt $channels ]; then
        if [ -z "$nostrict" ]; then
            >&2 echo "ERROR: ref_channel ($ref_channel) > number of audio channels ($channels)"
            exit 1
        elif [ $channels -eq 1 ]; then
            sox "$audio_path" "$output_path" remix 1
            echo -n "$(realpath $relative_to $output_path)"
        else
            >&2 echo "ERROR: ref_channel ($ref_channel) > number of audio channels ($channels)"
            exit 1
        fi
    elif [ $channels -eq 1 ] && [ $ref_channel -eq $channels ]; then
        echo -n "$(realpath $relative_to $audio_path)"
    else
        sox "$audio_path" "$output_path" remix $ref_channel
        echo -n "$(realpath $relative_to $output_path)"
    fi
}

SECONDS=0

help_message=$(cat << EOF
Usage:
    $0 [--fs <fs>] [--mode <mode>] [--ref_channel <ref_channel>] [--nostrict <any_value>] [--out <out_file>] <ref.scp> <inf.scp>
or
    $0 [--fs <fs>] [--ref_channel <ref_channel>] [--out <out_file>] <ref.wav> <inf.wav>

    required argument:
        <ref.scp>: a scp file containing the path to reference signals
        <inf.scp>: a scp file containing the path to degraded/enhanced signals
        or
        <ref.wav>: a reference audio file
        <inf.wav>: a degraded/enhanced audio file
    optional argument:
        --fs: sample rate in Hz; supported values: 16000 (default) or 8000
        --mode: "wb" (wideband/P.862.2) or "nb" (narrowband/P.862, default)
        --ref_channel: reference channel (default: 0) to be used in the signals
        --nostrict: if specified, the ref_channel is allowed to be larger than number of channels (=1) in the audio, where ref_channel does not take effect
        --out: output file; default is "-", which means writing to stdout
EOF
)

fs=16000
mode="nb"
ref_channel=0
out="-"
nostrict=
echo $PWD

#log "$0 $*"
. utils/parse_options.sh

. ./path.sh || exit 1;
. ./cmd.sh || exit 1;


if [ $# -ne 2 ]; then
    log "${help_message}"
    exit 2
fi
if [ "$mode" = "wb" ]; then
    _opt=" +wb"
else
    _opt=""
fi

ref=$1
inf=$2
ref_channel=$((ref_channel + 1))

if [[ "$fs" == "16000" ]] || [[ "${fs,,}" == "16k" ]]; then
    fs=16000
elif [[ "$fs" == "8000" ]] || [[ "${fs,,}" == "8k" ]]; then
    fs=8000
else
    log "Error: sample rate must be either 16000 or 8000: ${fs}"
    exit 1
fi

if ! command -v "PESQ" &> /dev/null; then
    log "Could not find (or execute) the PESQ program"
    log "cd tools; ./install_pesq.sh"
    exit 1
fi

if ! command -v "sox" &> /dev/null; then
    log "Could not find (or execute) the sox program"
    exit 1
fi
if [ -n "$out" ] && [ "$out" != "-" ]; then
    if [ -e "$out" ]; then
        echo "Warning: '$out' will be overwritten"
        echo -n > "$out"
    else
        mkdir -p "$(dirname $out)"
        touch "$out"
        echo "Writing to '$out'"
    fi
    out="$(realpath $out)"
fi

if [[ "${ref##*.}" != "${inf##*.}" ]]; then
    log "<ref> and <inf> files must have the same extension"
    exit 1
elif [[ "${ref##*.}" == "scp" ]]; then
    tmpdir=$(mktemp -d XXXX.pesq)
    while read -r uttid ref_path inf_path; do
        ref_wav=$(get_audio_in_ref_channel "$ref_path" "$ref_channel" "${tmpdir}/ref.wav" "${tmpdir}" ${nostrict:+$nostrict})
        inf_wav=$(get_audio_in_ref_channel "$inf_path" "$ref_channel" "${tmpdir}/inf.wav" "${tmpdir}" ${nostrict:+$nostrict})
        (
            cd "$tmpdir"
            PESQ +${fs}${_opt} "$ref_wav" "$inf_wav" || (
                set +e
                set -x
                info=$(PESQ +${fs}${_opt} "$ref_wav" "$inf_wav" | tail -n 1)
                set +x
                >&2 echo $info
            )
            col=$(head -n1 pesq_results.txt | awk '{for(i=1; i<=NF; i++) {if($i == "MOSLQO") {print i; break}}}')
            pesq_score=$(tail -n1 pesq_results.txt | cut -f $col | sed -e 's/\s\+//')
            if [ -n "$out" ] && [ "$out" != "-" ]; then
                echo "$uttid $pesq_score" >> "$out"
            else
                echo "$uttid $pesq_score"
            fi
        )
    done < <(awk 'FNR==NR{a[$1]=$2; next}{print $1, "\t", a[$1], "\t", $2}' "$ref" "$inf")
    rm -r "$tmpdir"
else
    tmpdir=$(mktemp -d XXXX.pesq)
    ref_wav=$(get_audio_in_ref_channel "$ref" "$ref_channel" "${tmpdir}/ref.wav" "${tmpdir}" ${nostrict:+$nostrict})
    inf_wav=$(get_audio_in_ref_channel "$inf" "$ref_channel" "${tmpdir}/inf.wav" "${tmpdir}" ${nostrict:+$nostrict})
    (
        cd "$tmpdir"
        PESQ +${fs}${_opt} "$ref_wav" "$inf_wav" || (
            echo -e "\nPESQ +${fs}${_opt} \"$ref_wav\" \"$inf_wav\" | tail -n 1"
            PESQ +${fs}${_opt} "$ref_wav" "$inf_wav" | tail -n 1
        )
        col=$(head -n1 pesq_results.txt | awk '{for(i=1; i<=NF; i++) {if($i == "MOSLQO") {print i; break}}}')
        pesq_score=$(tail -n1 pesq_results.txt | cut -f $col | sed -e 's/\s\+//')
        echo $pesq_score
    )
    rm -r "$tmpdir"
fi
echo -n
