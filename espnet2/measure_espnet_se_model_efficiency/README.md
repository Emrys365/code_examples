A minimal example of evaluating the computational efficiency of ESPnet-SE models
-----

### Prerequisite
1. pip install espnet

### Steps
1. Clone the official ESPnet repository to anywhere you like, say ${espnet_path}
2. Copy the Python scripts in this folder to ${espnet_path}
3. Run the following command under the folder ${espnet_path} to measure the computational cost (#MACs) and the peak GPU memory usage of an ESPnet-SE model (specified by a model configuration file):
  ```python
  python -m espnet2.bin.enh_train --config "egs2/wsj0_2mix/enh1/conf/tuning/train_enh_conv_tasnet.yaml" --iterator_type none --dry_run true --output_dir tmp

  python get_model_meta.py --enh_config tmp/config.yaml --fs 8000 --is_tse False

  CUDA_VISIBLE_DEVICES=0 python get_gpu_consumption_batch.py --enh_config tmp/config.yaml --fs 8000 --is_tse False
  ```

