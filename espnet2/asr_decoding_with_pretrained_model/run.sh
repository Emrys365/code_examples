#!/usr/bin/env bash

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail


log() {
    local fname=${BASH_SOURCE[1]##*/}
    echo -e "$(date '+%Y-%m-%dT%H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}
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
SECONDS=0


# General configuration
stage=9              # Processes starts from the specified stage.
stop_stage=10000     # Processes is stopped at the specified stage.
inference_nj=16      # The number of parallel jobs in inference.
gpu_inference=false  # Whether to perform gpu inference.
expdir=exp           # Directory to save experiments.
python=python3       # Specify python to execute espnet commands.

# [Task dependent] Set the datadir name created by local/data.sh
datadir=data         # Kaldi-style data directory
test_sets=           # Names of test sets. Multiple items can be specified.
nlsyms_txt=none      # Non-linguistic symbol list if existing.
cleaner=none         # Text cleaner.
lang=noinfo          # The language type of corpus.
score_opts=          # The options given to sclite scoring
local_score_opts=    # The options given to local/score.sh.

# Feature extraction related
audio_format=wav     # Audio format: wav, flac, wav.ark, flac.ark  (only in feats_type=raw).

# Tokenization related (Make sure this part matches the model config!)
token_type=bpe       # Tokenization type (char or bpe).
nbpe=30             # The number of BPE vocabulary.
bpemode=unigram      # Mode of BPE (unigram or bpe).

# Decoding related
asr_exp=""           # ASR model directory for scoring WER (downloaded or to be downloaded to)
use_lm=true          # Use language model for ASR decoding.
use_word_lm=false    # Whether to use word language model.
lm_exp=""            # LM model directory for scoring WER
inference_tag=       # Suffix to the result dir for decoding.
inference_config=    # YAML config for decoding.
inference_args=      # Arguments for decoding, e.g., "--lm_weight 0.1".
                     # Note that it will overwrite args in inference config.
inference_lm=valid.loss.ave.pth       # Language modle name for decoding.
inference_asr_model=valid.acc.ave.pth # ASR model name for decoding.
                                      # e.g.
                                      # inference_asr_model=train.loss.best.pth
                                      # inference_asr_model=3epoch.pth
                                      # inference_asr_model=valid.acc.best.pth
                                      # inference_asr_model=valid.loss.ave.pth
download_model=      # Download a model from Model Zoo and use it for decoding.
                     # e.g.
                     # download_model="Shinji Watanabe/librispeech_asr_train_asr_transformer_e18_raw_bpe_sp_valid.acc.best"


. utils/parse_options.sh

if [ $# -ne 0 ]; then
    log "Error: No positional arguments are required."
    exit 2
fi

. ./cmd.sh


[ -z "${test_sets}" ] && { log "Error: --test_sets is required"; exit 2; };

# Check tokenization type
if [ "${lang}" != noinfo ]; then
    token_listdir=data/${lang}_token_list
else
    token_listdir=data/token_list
fi
bpedir="${token_listdir}/bpe_${bpemode}${nbpe}"
bpeprefix="${bpedir}"/bpe
bpemodel="${bpeprefix}".model

if [ "${token_type}" = char ] || [ "${token_type}" = word ]; then
    bpemodel=none
fi
if ${use_word_lm}; then
    log "Error: Word LM is not supported yet"
    exit 2
fi


if [ -n "${download_model}" ]; then
    log "Use ${download_model} for decoding and evaluation"
    asr_exp="${expdir}/${download_model// /_}"
    mkdir -p "${asr_exp}"

    # If the model already exists, you can skip downloading
    espnet_model_zoo_download --unpack true "${download_model}" > "${asr_exp}/config.txt"

    # Get the path of each file
    _asr_model_file=$(<"${asr_exp}/config.txt" sed -e "s/.*'asr_model_file': '\([^']*\)'.*$/\1/")
    _asr_train_config=$(<"${asr_exp}/config.txt" sed -e "s/.*'asr_train_config': '\([^']*\)'.*$/\1/")

    # Get token_type
    token_type=$(<"${_asr_train_config}" grep -Eo "^token_type: (\w+)$" | awk '{print $2}')
    if [ "${token_type}" = "bpe" ]; then
        bpemodel=$(<"${_asr_train_config}" grep -Eo "^bpemodel: .*$" | awk '{print $2}' | sed -e 's/^"\(.*\)"/\1/' -e "s/^'\(.*\)'/\1/")
        if [ -z "${bpemodel}" ]; then
            log "Invalid model: token_type=bpe, but 'bpemodel' is not defined in '${_asr_train_config}'"
            exit 1
        elif [ ! -f "${bpemodel}" ]; then
            log "No such file for 'bpemodel': ${bpemodel}"
            exit 1
        fi
        nbpe_mode=$(echo "${bpemodel}" | grep -Po "(?<=/bpe_)\w+(?=/bpe\.model$)")
        nbpe=$(echo "${nbpe_mode}" | grep -Po "\d+")
        bpemode=$(echo "${nbpe_mode}" | grep -Po "[a-zA-Z]+")
    else
        bpemodel=none
    fi

    # Create symbolic links
    ln -sf "${_asr_model_file}" "${asr_exp}"
    ln -sf "${_asr_train_config}" "${asr_exp}"
    inference_asr_model=$(basename "${_asr_model_file}")

    if [ "$(<${asr_exp}/config.txt grep -c lm_file)" -gt 0 ]; then
        _lm_file=$(<"${asr_exp}/config.txt" sed -e "s/.*'lm_file': '\([^']*\)'.*$/\1/")
        _lm_train_config=$(<"${asr_exp}/config.txt" sed -e "s/.*'lm_train_config': '\([^']*\)'.*$/\1/")

        lm_exp="${expdir}/${download_model// /_}/lm"
        mkdir -p "${lm_exp}"

        ln -sf "${_lm_file}" "${lm_exp}"
        ln -sf "${_lm_train_config}" "${lm_exp}"
        inference_lm=$(basename "${_lm_file}")
    fi
fi


if [ -z "${inference_tag}" ]; then
    if [ -n "${inference_config}" ]; then
        inference_tag="$(basename "${inference_config}" .yaml)"
    else
        inference_tag=inference
    fi
    # Add overwritten arg's info
    if [ -n "${inference_args}" ]; then
        inference_tag+="$(echo "${inference_args}" | sed -e "s/--/\_/g" -e "s/[ |=]//g")"
    fi
    if "${use_lm}"; then
        inference_tag+="_lm_$(basename "${lm_exp}")_$(echo "${inference_lm}" | sed -e "s/\//_/g" -e "s/\.[^.]*$//g")"
    fi
    inference_tag+="_asr_model_$(echo "${inference_asr_model}" | sed -e "s/\//_/g" -e "s/\.[^.]*$//g")"
fi


if [ ${stage} -le 9 ] && [ ${stop_stage} -ge 9 ]; then
    log "Stage 9: Decode with pretrained ASR model: "

    if ${gpu_inference}; then
        _cmd="${cuda_cmd}"
        _ngpu=1
    else
        _cmd="${decode_cmd}"
        _ngpu=0
    fi

    _opts=
    if [ -n "${inference_config}" ]; then
        _opts+="--config ${inference_config} "
    fi
    if "${use_lm}"; then
        if "${use_word_lm}"; then
            _opts+="--word_lm_train_config ${lm_exp}/config.yaml "
            _opts+="--word_lm_file ${lm_exp}/${inference_lm} "
        else
            _opts+="--lm_train_config ${lm_exp}/config.yaml "
            _opts+="--lm_file ${lm_exp}/${inference_lm} "
        fi
    fi

    for dset in ${test_sets}; do
        _data="${datadir}/${dset}"
        _dir="${asr_exp}/${inference_tag}/${dset}"
        _logdir="${_dir}/logdir"
        mkdir -p "${_logdir}"

        if [ -e "${_data}/feats_type" ]; then
            _feats_type="$(<${_data}/feats_type)"
        else
            _feats_type=raw
        fi
        if [ "${_feats_type}" = raw ]; then
            _scp=wav.scp
            if [[ "${audio_format}" == *ark* ]]; then
                _type=kaldi_ark
            else
                _type=sound
            fi
        else
            _scp=feats.scp
            _type=kaldi_ark
        fi

        # 1. Split the key file
        key_file=${_data}/${_scp}
        split_scps=""
        _nj=$(min "${inference_nj}" "$(<${key_file} wc -l)")
        for n in $(seq "${_nj}"); do
            split_scps+="${_logdir}/keys.${n}.scp "
        done
        # shellcheck disable=SC2086
        utils/split_scp.pl "${key_file}" ${split_scps}

        # 2. Submit decoding jobs
        log "Decoding started... log: '${_logdir}/asr_inference.*.log'"
        # shellcheck disable=SC2086
        ${_cmd} --gpu "${_ngpu}" JOB=1:"${_nj}" "${_logdir}"/asr_inference.JOB.log \
            ${python} -m espnet2.bin.asr_inference \
                --ngpu "${_ngpu}" \
                --data_path_and_name_and_type "${_data}/${_scp},speech,${_type}" \
                --key_file "${_logdir}"/keys.JOB.scp \
                --asr_train_config "${asr_exp}"/config.yaml \
                --asr_model_file "${asr_exp}"/"${inference_asr_model}" \
                --output_dir "${_logdir}"/output.JOB \
                ${_opts} ${inference_args}

        # 3. Concatenates the output files from each jobs
        for f in token token_int score text; do
            for i in $(seq "${_nj}"); do
                cat "${_logdir}/output.${i}/1best_recog/${f}"
            done | LC_ALL=C sort -k1 >"${_dir}/${f}"
        done
    done
fi


if [ ${stage} -le 10 ] && [ ${stop_stage} -ge 10 ]; then
    log "Stage 10: Scoring"
    if [ "${token_type}" = pnh ]; then
        log "Error: Not implemented for token_type=phn"
        exit 1
    fi

    for dset in ${test_sets}; do
        _data="${datadir}/${dset}"
        _dir="${asr_exp}/${inference_tag}/${dset}"

        for _type in cer wer ter; do
            [ "${_type}" = ter ] && [ ! -f "${bpemodel}" ] && continue

            _scoredir="${_dir}/score_${_type}"
            mkdir -p "${_scoredir}"

            if [ "${_type}" = wer ]; then
                # Tokenize text to word level
                paste \
                    <(<"${_data}/text" \
                            ${python} -m espnet2.bin.tokenize_text  \
                                -f 2- --input - --output - \
                                --token_type word \
                                --non_linguistic_symbols "${nlsyms_txt}" \
                                --remove_non_linguistic_symbols true \
                                --cleaner "${cleaner}" \
                                ) \
                    <(<"${_data}/utt2spk" awk '{ print "(" $2 "-" $1 ")" }') \
                        >"${_scoredir}/ref.trn"

                # NOTE(kamo): Don't use cleaner for hyp
                paste \
                    <(<"${_dir}/text"  \
                            ${python} -m espnet2.bin.tokenize_text  \
                                -f 2- --input - --output - \
                                --token_type word \
                                --non_linguistic_symbols "${nlsyms_txt}" \
                                --remove_non_linguistic_symbols true \
                                ) \
                    <(<"${_data}/utt2spk" awk '{ print "(" $2 "-" $1 ")" }') \
                        >"${_scoredir}/hyp.trn"


            elif [ "${_type}" = cer ]; then
                # Tokenize text to char level
                paste \
                    <(<"${_data}/text" \
                            ${python} -m espnet2.bin.tokenize_text  \
                                -f 2- --input - --output - \
                                --token_type char \
                                --non_linguistic_symbols "${nlsyms_txt}" \
                                --remove_non_linguistic_symbols true \
                                --cleaner "${cleaner}" \
                                ) \
                    <(<"${_data}/utt2spk" awk '{ print "(" $2 "-" $1 ")" }') \
                        >"${_scoredir}/ref.trn"

                # NOTE(kamo): Don't use cleaner for hyp
                paste \
                    <(<"${_dir}/text"  \
                            ${python} -m espnet2.bin.tokenize_text  \
                                -f 2- --input - --output - \
                                --token_type char \
                                --non_linguistic_symbols "${nlsyms_txt}" \
                                --remove_non_linguistic_symbols true \
                                ) \
                    <(<"${_data}/utt2spk" awk '{ print "(" $2 "-" $1 ")" }') \
                        >"${_scoredir}/hyp.trn"

            elif [ "${_type}" = ter ]; then
                # Tokenize text using BPE
                paste \
                    <(<"${_data}/text" \
                            ${python} -m espnet2.bin.tokenize_text  \
                                -f 2- --input - --output - \
                                --token_type bpe \
                                --bpemodel "${bpemodel}" \
                                --cleaner "${cleaner}" \
                            ) \
                    <(<"${_data}/utt2spk" awk '{ print "(" $2 "-" $1 ")" }') \
                        >"${_scoredir}/ref.trn"

                # NOTE(kamo): Don't use cleaner for hyp
                paste \
                    <(<"${_dir}/text" \
                            ${python} -m espnet2.bin.tokenize_text  \
                                -f 2- --input - --output - \
                                --token_type bpe \
                                --bpemodel "${bpemodel}" \
                                ) \
                    <(<"${_data}/utt2spk" awk '{ print "(" $2 "-" $1 ")" }') \
                        >"${_scoredir}/hyp.trn"

            fi

            sclite \
        ${score_opts} \
                -r "${_scoredir}/ref.trn" trn \
                -h "${_scoredir}/hyp.trn" trn \
                -i rm -o all stdout > "${_scoredir}/result.txt"

            log "Write ${_type} result in ${_scoredir}/result.txt"
            grep -e Avg -e SPKR -m 2 "${_scoredir}/result.txt"
        done
    done

    [ -f local/score.sh ] && local/score.sh ${local_score_opts} "${asr_exp}"

    # Show results in Markdown syntax
    scripts/utils/show_asr_result.sh "${asr_exp}" > "${asr_exp}"/RESULTS.md
    cat "${asr_exp}"/RESULTS.md

fi