#!/bin/bash

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

min() {
  local a b
  a=$1
  for b in "$@"; do
      if [ "${b}" -le "${a}" ]; then
          a="${b}"
      fi
  done
  echo "${a}"
}

. ./path.sh
. ./cmd.sh

nj=20
fs=16000
ref_channel=0
mode="nb"

ref_scp=
inf_scp=
out=result_pesq.txt

. utils/parse_options.sh


tmpdir=$(mktemp -d pesq_score-XXXX)
chmod 755 "$tmpdir"
# echo "Creating temporary directory: $tmpdir"
logdir="$PWD"/log
mkdir -p "$logdir"

_nj=$(min "${nj}" "$(<${ref_scp} wc -l)")
split_scps=""
for n in $(seq "${_nj}"); do
    split_scps+=" ${tmpdir}/ref.${n}.scp"
done
# shellcheck disable=SC2086
utils/split_scp.pl "${ref_scp}" ${split_scps}
split_scps=""
for n in $(seq "${_nj}"); do
    split_scps+=" ${tmpdir}/inf.${n}.scp"
done
# shellcheck disable=SC2086
utils/split_scp.pl "${inf_scp}" ${split_scps}


out="$(realpath $out)"
${decode_cmd} JOB=1:"${_nj}" "${logdir}/compute_$(basename $tmpdir)".JOB.log \
    ./compute-pesq-score.sh \
        --ref_channel ${ref_channel} \
        --nostrict True \
        --fs ${fs} \
        --mode ${mode} \
        --out "$tmpdir"/PESQ.JOB \
        "$tmpdir"/ref.JOB.scp \
        "$tmpdir"/inf.JOB.scp \

echo -n > "$tmpdir"/PESQ.tmp
for j in $(seq ${_nj}); do
    cat "$tmpdir"/PESQ.${j} >> "$tmpdir"/PESQ.tmp
done
sort "$tmpdir"/PESQ.tmp > "${out}"

awk 'BEGIN{sum=0}
    {n=0;score=0; for (i=2; i<=NF; i+=2){n+=1;score+=$i}; sum+=score/n}
    END{print "mean PESQ: " sum/NR}' "${out}"

rm -r $tmpdir
