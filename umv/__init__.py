"""U-MV: U-shaped MambaVision segmentation framework for *Acacia tortilis*
crown mapping from ultra-high-resolution UAV imagery.

Importing this package registers the custom backbone, decode head and
dataset with the MMSegmentation registries.  Configuration files reference
it through::

    custom_imports = dict(imports=['umv'], allow_failed_imports=False)
"""
from .version import __version__  # noqa: F401
from . import datasets, models  # noqa: F401  (registration side effects)


def _register_checkpoint_loader():
    """Make mmengine's local checkpoint loader work under PyTorch >= 2.6.

    torch.load defaults to ``weights_only=True`` since 2.6; mmengine 0.10.x calls it
    without the argument, and its checkpoints contain ``message_hub`` objects that the
    restricted unpickler rejects (``Unsupported global: ... HistoryBuffer``).  The
    checkpoints handled here are the project's own files, so the full unpickler is used.
    """
    import os.path as osp

    import torch
    from mmengine.runner.checkpoint import CheckpointLoader

    @CheckpointLoader.register_scheme(prefixes='', force=True)
    def _load_from_local(filename, map_location):
        filename = osp.expanduser(filename)
        if not osp.isfile(filename):
            raise FileNotFoundError(f'{filename} can not be found.')
        try:
            return torch.load(filename, map_location=map_location, weights_only=False)
        except TypeError:  # torch < 1.13 has no weights_only argument
            return torch.load(filename, map_location=map_location)


try:  # never let a registry change break "import umv"; the Docker image also sets
    _register_checkpoint_loader()  # TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 as a second safeguard
except Exception as _e:  # noqa: BLE001
    import warnings
    warnings.warn(f'could not register the U-MV checkpoint loader ({_e}); if loading a checkpoint '
                  'fails with "Weights only load failed", set TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1')

__all__ = ['__version__', 'models', 'datasets']
