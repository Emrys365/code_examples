#!/bin/bash

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


data_feats=dump/raw
enh_exp=exp/original_input_raw
inference_nj=32
ref_channel=0
scoring_protocol="STOI SDR SAR SIR SI_SNR"
spk_num=2

test_sets=

. utils/parse_options.sh
. ./cmd.sh
. ./path.sh

[ -z "${test_sets}" ] && { log "Error: --test_sets is required"; exit 2; };


mkdir -p "${enh_exp}"

echo 'config: original_input' > "${enh_exp}/config.yaml"
python3 -m espnet2.bin.enh_train --print_config --optim adam >> "${enh_exp}/config.yaml"
for dset in ${test_sets}; do
    _data="${data_feats}/${dset}"
    _dir="${enh_exp}/enhanced_${dset}/scoring"
    _logdir="${_dir}/logdir"
    mkdir -p "${_logdir}"

    # 1. Split the key file
    key_file=${_data}/wav.scp
    split_scps=""
    _nj=$(min "${inference_nj}" "$(<${key_file} wc -l)")
    for n in $(seq "${_nj}"); do
        split_scps+=" ${_logdir}/keys.${n}.scp"
        mkdir -p ${_logdir}/output.${n}
    done
    # shellcheck disable=SC2086
    utils/split_scp.pl "${key_file}" ${split_scps}

    _ref_scp=""
    _inf_scp=""
    for spk in $(seq "${spk_num}"); do
        _ref_scp+="--ref_scp ${_data}/spk${spk}.scp "
        _inf_scp+="--inf_scp ${_data}/wav.scp "
    done

    ${decode_cmd} JOB=1:"${_nj}" "${_logdir}"/enh_scoring.JOB.log \
        python3 -m espnet2.bin.enh_scoring \
            --key_file "${_logdir}"/keys.JOB.scp \
            --output_dir "${_logdir}"/output.JOB \
            ${_ref_scp} \
            ${_inf_scp} \
            --enh_train_config "${enh_exp}/config.yaml" \
            --ref_channel ${ref_channel}

    for spk in $(seq "${spk_num}"); do
        for protocol in ${scoring_protocol} wav; do
            for i in $(seq "${_nj}"); do
                cat "${_logdir}/output.${i}/${protocol}_spk${spk}"
            done | LC_ALL=C sort -k1 > "${_dir}/${protocol}_spk${spk}"
        done
    done


    for protocol in ${scoring_protocol}; do
        # shellcheck disable=SC2046
        paste $(for j in $(seq ${spk_num}); do echo "${_dir}"/"${protocol}"_spk"${j}" ; done)  |
        awk 'BEGIN{sum=0}
            {n=0;score=0;for (i=2; i<=NF; i+=2){n+=1;score+=$i}; sum+=score/n}
            END{print sum/NR}' > "${_dir}/result_${protocol,,}.txt"
    done
done
./scripts/utils/show_enh_score.sh ${enh_exp} > "${enh_exp}/RESULTS.TXT"
