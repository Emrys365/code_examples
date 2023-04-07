#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse

import torch
from thop import profile

from espnet2.tasks.enh import EnhancementTask
from espnet2.tasks.enh_tse import TargetSpeakerExtractionTask
from espnet2.torch_utils.model_summary import model_summary
from espnet2.utils import config_argparse
from espnet2.utils.types import str2bool


def compute_macs(model, fs=8000, is_tse=False):
    # dur = 30
    dur = 4

    device = next(model.parameters()).device
    input = torch.rand((1, fs * dur)).to(device)
    lengths = torch.LongTensor([fs * dur]).to(device)
    flops_enc, _ = profile(model=model.encoder, inputs=(input, lengths))
    feature, flen = model.encoder(input, lengths)

    if is_tse:
        # feature_aux = torch.rand((1, model.extractor.spk_embed_dim)).to(device)
        # flen_aux = torch.LongTensor([1]).to(device)

        flops_enc = flops_enc * 2
        aux = torch.rand((1, fs * dur)).to(device)
        feature_aux, flen_aux = model.encoder(aux, lengths)
        flops_sep, _ = profile(
            model=model.extractor, inputs=(feature, flen, feature_aux, flen_aux)
        )
    else:
        flops_sep, _ = profile(model=model.separator, inputs=(feature, flen))

    lens = lengths

    flops_dec, _ = profile(model=model.decoder, inputs=(feature, lens))

    return flops_enc / dur, flops_sep / dur, flops_dec / dur


def get_meta(config, fs, is_tse=False):
    # model_file = f'{exp_dir}/{model}'

    if is_tse:
        enh_model, enh_train_args = TargetSpeakerExtractionTask.build_model_from_file(
            config, None
        )
    else:
        enh_model, enh_train_args = EnhancementTask.build_model_from_file(config, None)
    enh_model.to(dtype=getattr(torch, "float32")).eval()

    message = model_summary(enh_model)
    macs = compute_macs(model=enh_model, fs=fs, is_tse=is_tse)
    macs = [m / 1024 / 1024 / 1024 for m in macs]
    message += f"\n   Enc Macs: {macs[0]} G/s\n"
    message += f"   Sep Macs: {macs[1]} G/s\n"
    message += f"   Dec Macs: {macs[2]} G/s\n"
    message += f"   Tol Macs: {sum(macs)} G/s\n"
    print(message)


def get_parser():
    parser = config_argparse.ArgumentParser(
        description="Frontend inference",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    group = parser.add_argument_group("The model configuration related")
    group.add_argument("--enh_config", type=str, help="Model config file")
    group.add_argument("--fs", type=int, help="samplerate", default=8000)
    group.add_argument("--is_tse", type=str2bool, help="Whether to use TSE model")

    return parser


def main(cmd=None):
    parser = get_parser()
    args = parser.parse_args(cmd)
    print(args)
    # kwargs = vars(args)
    get_meta(config=args.enh_config, fs=args.fs, is_tse=args.is_tse)


if __name__ == "__main__":
    main()
