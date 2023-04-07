#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
from collections import defaultdict

import torch

from espnet2.tasks.enh import EnhancementTask
from espnet2.tasks.enh_tse import TargetSpeakerExtractionTask
from espnet2.torch_utils.model_summary import model_summary
from espnet2.utils import config_argparse
from espnet2.utils.types import str2bool


def measure_gpu_memory(model, fs=8000, is_tse=False):
    # dur = 30
    dur = 4
    dur_enroll = 4

    device = next(model.parameters()).device
    refs = {
        f"speech_ref{spk + 1}": torch.rand((1, fs * dur), device=device)
        for spk in range(model.num_spk)
    }
    others = {}
    if is_tse:
        # others = {
        #     f"enroll_ref{spk + 1}": torch.rand(
        #         (1, model.extractor.spk_embed_dim), device=device
        #     )
        #     for spk in range(model.num_spk)
        # }
        others = {
            f"enroll_ref{spk + 1}": torch.rand((1, fs * dur_enroll), device=device)
            for spk in range(model.num_spk)
        }
    batch = {
        "speech_mix": torch.rand((1, fs * dur), device=device),
        "speech_mix_lengths": torch.LongTensor([fs * dur], device="cpu"),
        **refs,
        **others,
    }
    mem_pre = measure_gpu_max_memory_usage()

    loss, _, _ = model(**batch)
    mem_forward = measure_gpu_max_memory_usage()

    if model.training:
        loss.backward()
        mem_backward = measure_gpu_max_memory_usage()
    else:
        mem_backward = 0

    return mem_pre, mem_forward, mem_backward


def get_meta(config, fs, is_tse=False, mode="eval"):
    # model_file = f'{exp_dir}/{model}'

    if not torch.cuda.is_available():
        raise ValueError("cuda is not available")
    device = torch.device("cuda")
    print("device: {}".format(device))

    if is_tse:
        enh_model, enh_train_args = TargetSpeakerExtractionTask.build_model_from_file(
            config, None
        )
    else:
        enh_model, enh_train_args = EnhancementTask.build_model_from_file(config, None)
    enh_model.to(dtype=getattr(torch, "float32"))
    if mode == "eval":
        enh_model.eval()
    enh_model.to(device)

    mems = defaultdict(list)
    for _ in range(10):
        # repeat 10 times to get the averaged peak memory
        torch.cuda.empty_cache()
        torch.cuda.reset_peak_memory_stats()

        mem_pre, mem_forward, mem_backward = measure_gpu_memory(
            model=enh_model, fs=fs, is_tse=is_tse
        )
        if enh_model.training:
            enh_model.zero_grad()
        mems["pre"].append(mem_pre)
        mems["forward"].append(mem_forward)
        mems["backward"].append(mem_backward)

    for name, l in mems.items():
        print(f"    {name} Peak GPU memory: {sum(l) / len(l)} GiB", flush=True)


def measure_gpu_max_memory_usage():
    assert torch.cuda.is_available()
    mem = torch.cuda.max_memory_allocated()
    return mem / 2**30


def get_parser():
    parser = config_argparse.ArgumentParser(
        description="Frontend inference",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    group = parser.add_argument_group("The model configuration related")
    group.add_argument("--enh_config", type=str, nargs="+", help="Model config file")
    group.add_argument("--fs", type=int, help="samplerate", default=8000)
    group.add_argument("--is_tse", type=str2bool, help="Whether to use TSE model")

    return parser


def main(cmd=None):
    parser = get_parser()
    args = parser.parse_args(cmd)
    print(args)
    # kwargs = vars(args)
    for config in args.enh_config:
        for mode in ("train", "eval"):
            print(f"=== {config} ({mode}) ===", flush=True)
            get_meta(config=config, fs=args.fs, is_tse=args.is_tse, mode=mode)


if __name__ == "__main__":
    main()
