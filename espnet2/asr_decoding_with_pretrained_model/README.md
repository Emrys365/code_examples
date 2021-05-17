A minimal example of decoding with a pretrained ESPnet2 ASR model
-----

### Prerequisite
1. pip install espnet
2. pip install espnet_model_zoo

### Steps
1. Copy this directory to anywhere you like, say ${demo_dir}
2. Prepare a [Kaldi-style](https://kaldi-asr.org/doc/data_prep.html) data directory under ${demo_dir}, with the stucture like:
    ```
    ${demo_dir}
    ├── cmd.sh
    ├── data
    │   ├── test_16k_max
    │   │   ├── text
    │   │   ├── utt2spk
    │   │   └── wav.scp
    │   └── another_test_set
    │       ├── text
    │       ├── utt2spk
    │       └── wav.scp
    ├── run_asr.sh
    ├── scripts/utils/show_asr_result.sh
    └── utils/
    ```
    * **You need to create the following files by yourself:**
        * The `text` file in each subset directory contains the transcript for every utterance ID.
        * The `utt2spk` file in each subset directory contains the mapping from utterance ID to speaker ID.
        * The `wav.scp` file in each subset directory contains the audio path for every utterance ID.
3. (Optional) Modify `cmd_backend='local'` in [cmd.sh](https://github.com/Emrys365/code_examples/blob/master/espnet2/asr_decoding_with_pretrained_model/cmd.sh) according to your needs.
4. Run [run.sh](https://github.com/Emrys365/code_examples/blob/master/espnet2/asr_decoding_with_pretrained_model/run.sh) to start decoding and scoring:
    ```bash
    ./run.sh --inference_nj 10 --test_sets "test_16k_max another_test_set" --download_model "Shinji Watanabe/librispeech_asr_train_asr_transformer_e18_raw_bpe_sp_valid.acc.best"
    ```

    <details><summary>Expand to see an exmaple output</summary><div>

    ```bash
    ./run.sh --inference_nj 10 --test_sets "test_16k_max" --download_model "Shinji Watanabe/librispeech_asr_train_asr_transformer_e18_raw_bpe_sp_valid.acc.best"
    
    2021-05-17T12:30:32 (run_asr.sh:105:main) Use Shinji Watanabe/librispeech_asr_train_asr_transformer_e18_raw_bpe_sp_valid.acc.best for decoding and evaluation
    2021-05-17T12:30:47 (run_asr.sh:171:main) Stage 9: Decode with pretrained ASR model:
    2021-05-17T12:30:47 (run_asr.sh:229:main) Decoding started... log: 'exp/Shinji_Watanabe/librispeech_asr_train_asr_transformer_e18_raw_bpe_sp_valid.acc.best/inference_lm_lm_17epoch_asr_model_54epoch/test_16k_max/logdir/asr_inference.*.log'
    2021-05-17T12:37:38 (run_asr.sh:252:main) Stage 10: Scoring
    /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/bin/python3 /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/lib/python3.7/site-packages/espnet2/bin/tokenize_text.py -f 2- --input - --output - --token_type char --non_linguistic_symbols none --remove_non_linguistic_symbols true --cleaner none
    /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/bin/python3 /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/lib/python3.7/site-packages/espnet2/bin/tokenize_text.py -f 2- --input - --output - --token_type char --non_linguistic_symbols none --remove_non_linguistic_symbols true
    2021-05-17T12:37:42 (run_asr.sh:353:main) Write cer result in exp/Shinji_Watanabe/librispeech_asr_train_asr_transformer_e18_raw_bpe_sp_valid.acc.best/inference_lm_lm_17epoch_asr_model_54epoch/test_16k_max/score_cer/result.txt
    |      SPKR          |      # Snt           # Wrd       |      Corr              Sub               Del              Ins               Err            S.Err       |
    |      Sum/Avg       |       100             9922       |      95.2              0.9               3.8              1.4               6.2             73.0       |
    /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/bin/python3 /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/lib/python3.7/site-packages/espnet2/bin/tokenize_text.py -f 2- --input - --output - --token_type word --non_linguistic_symbols none --remove_non_linguistic_symbols true --cleaner none
    /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/bin/python3 /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/lib/python3.7/site-packages/espnet2/bin/tokenize_text.py -f 2- --input - --output - --token_type word --non_linguistic_symbols none --remove_non_linguistic_symbols true
    2021-05-17T12:37:45 (run_asr.sh:353:main) Write wer result in exp/Shinji_Watanabe/librispeech_asr_train_asr_transformer_e18_raw_bpe_sp_valid.acc.best/inference_lm_lm_17epoch_asr_model_54epoch/test_16k_max/score_wer/result.txt
    |      SPKR          |      # Snt           # Wrd       |      Corr              Sub               Del              Ins               Err            S.Err       |
    |      Sum/Avg       |       100             1645       |      87.3             10.5               2.2              3.3              16.0             73.0       |
    /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/bin/python3 /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/lib/python3.7/site-packages/espnet2/bin/tokenize_text.py -f 2- --input - --output - --token_type bpe --bpemodel /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/lib/python3.7/site-packages/espnet_model_zoo/653d10049fdc264f694f57b49849343e/data/token_list/bpe_unigram5000/bpe.model --cleaner none
    /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/bin/python3 /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/lib/python3.7/site-packages/espnet2/bin/tokenize_text.py -f 2- --input - --output - --token_type bpe --bpemodel /mnt/xlancefs/home/wyz97/anoaconda/venv/envs/py37/lib/python3.7/site-packages/espnet_model_zoo/653d10049fdc264f694f57b49849343e/data/token_list/bpe_unigram5000/bpe.model
    2021-05-17T12:37:48 (run_asr.sh:353:main) Write ter result in exp/Shinji_Watanabe/librispeech_asr_train_asr_transformer_e18_raw_bpe_sp_valid.acc.best/inference_lm_lm_17epoch_asr_model_54epoch/test_16k_max/score_ter/result.txt
    |      SPKR          |      # Snt           # Wrd       |      Corr              Sub               Del              Ins               Err            S.Err       |
    |      Sum/Avg       |       100             2692       |      79.1              7.2              13.7              2.0              22.9             73.0       |
    fatal: Not a git repository (or any parent up to mount point /mnt/xlancefs)
    Stopping at filesystem boundary (GIT_DISCOVERY_ACROSS_FILESYSTEM not set).
    fatal: Not a git repository (or any parent up to mount point /mnt/xlancefs)
    Stopping at filesystem boundary (GIT_DISCOVERY_ACROSS_FILESYSTEM not set).
    <!-- Generated by scripts/utils/show_asr_result.sh -->
    # RESULTS
    ## Environments
    - date: `Mon May 17 12:37:48 CST 2021`
    - python version: `3.7.10 (default, Feb 26 2021, 18:47:35)  [GCC 7.3.0]`
    - espnet version: `espnet 0.9.9`
    - pytorch version: `pytorch 1.5.1`
    - Git hash: ``
    - Commit date: ``

    ## librispeech_asr_train_asr_transformer_e18_raw_bpe_sp_valid.acc.best
    ### WER

    |dataset|Snt|Wrd|Corr|Sub|Del|Ins|Err|S.Err|
    |---|---|---|---|---|---|---|---|---|
    |inference_lm_lm_17epoch_asr_model_54epoch/test_16k_max|100|1645|87.3|10.5|2.2|3.3|16.0|73.0|

    ### CER

    |dataset|Snt|Wrd|Corr|Sub|Del|Ins|Err|S.Err|
    |---|---|---|---|---|---|---|---|---|
    |inference_lm_lm_17epoch_asr_model_54epoch/test_16k_max|100|9922|95.2|0.9|3.8|1.4|6.2|73.0|

    ### TER

    |dataset|Snt|Wrd|Corr|Sub|Del|Ins|Err|S.Err|
    |---|---|---|---|---|---|---|---|---|
    |inference_lm_lm_17epoch_asr_model_54epoch/test_16k_max|100|2692|79.1|7.2|13.7|2.0|22.9|73.0|
    ```

    </div></details>
