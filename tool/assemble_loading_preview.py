"""Assemble Flutter-rendered loading frames into a review GIF (requires Pillow).

Run `flutter test tool/render_loading_preview.dart` first, then this script.
"""

from pathlib import Path

from PIL import Image


def main():
    frame_paths = sorted(Path('/private/tmp/carty-loading-frames').glob('frame-*.png'))
    if len(frame_paths) != 32:
        raise SystemExit('Render all 32 Flutter frames before assembling the preview.')
    frames = []
    for path in frame_paths:
        with Image.open(path) as image:
            frames.append(image.convert('RGB'))
    if any(image.size != frames[0].size for image in frames):
        raise SystemExit('All loading preview frames must have the same dimensions.')
    palette = frames[0].quantize(colors=128)
    animation = [
        image.quantize(palette=palette, dither=Image.Dither.NONE) for image in frames
    ]
    output = Path(__file__).resolve().parents[1] / 'docs/previews/city-loading.gif'
    animation[0].save(
        output, save_all=True, append_images=animation[1:],
        duration=[70, 80] * 16, loop=0, disposal=2, optimize=False,
    )
    print(f'Created {output.name}: {len(animation)} frames, {frames[0].size[0]}px wide')


if __name__ == '__main__':
    main()
