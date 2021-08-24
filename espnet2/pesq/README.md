An example of computing PESQ scores for a list of audios in parallel
-----

### Prerequisite
1. Install [PESQ](https://github.com/Emrys365/code_examples/blob/master/espnet2/pesq/tools/install_pesq.sh), and add the `PESQ/P862_annex_A_2005_CD/source/` directory to $PATH

### Steps
1. Copy this directory to anywhere you like, say ${demo_dir}
2. Prepare two [Kaldi-style](https://kaldi-asr.org/doc/data_prep.html) scp files corresponding to the reference and the enhanced speech
    * `ref.scp`: each line contains the clean reference signal for the corresponding utterance ID.
    * `enh.scp`: each line contains the input audio path for the corresponding utterance ID.
3. (Optional) Modify `cmd_backend='local'` in [cmd.sh](https://github.com/Emrys365/code_examples/blob/master/espnet2/pesq/cmd.sh) according to your needs.
4. Run the following command to start evaluation:
    ```bash
    ./compute_pesq_score.sh --mode "nb" --ref_channel 0 --ref_scp dump/raw/test/spk1.scp --inf_scp exp/enhanced/spk1.scp --out exp/enhanced/PESQ_spk1.scp
    ```

    <details><summary>Expand to see an example output</summary><div>

    ```bash
    $ ./compute_pesq_score.sh --mode "nb" --ref_channel 0 --ref_scp dump/raw/test/spk1.scp --inf_scp exp/enhanced/spk1.scp --out exp/enhanced/PESQ_spk1.scp

    mean PESQ: 3.32452
    ```

    ```bash
    $ ./compute_pesq_score.sh --mode "wb" --ref_channel 0 --ref_scp dump/raw/test/spk1.scp --inf_scp exp/enhanced/spk1.scp --out exp/enhanced/PESQ_spk1.scp
    
    mean PESQ: 2.73225
    ```

    </div></details>
