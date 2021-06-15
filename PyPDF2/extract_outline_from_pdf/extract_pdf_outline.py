import sys

from distutils.version import LooseVersion
from os.path import exists
from PyPDF2 import PdfFileReader


is_python2 = LooseVersion(sys.version) < "3"


def _parse_outline_tree(reader, outline_tree, level=0):
    """Return List[Tuple[level(int), page(int), title(str)]]"""
    ret = []
    for heading in outline_tree:
        if isinstance(heading, list):
            # contains sub-headings
            ret.extend(_parse_outline_tree(reader, heading, level=level + 1))
        else:
            ret.append((level, reader.getDestinationPageNumber(heading), heading.title))
    return ret


def extractOutline(pdf_path, outline_txt_path):
    if not exists(pdf_path):
        return "Error: No such file: {}".format(pdf_path)
    if exists(outline_txt_path):
        print("Warning: Overwritting {}".format(outline_txt_path))

    reader = PdfFileReader(pdf_path)
    # List of ('Destination' objects) or ('Destination' object lists)
    #  [{'/Type': '/Fit', '/Title': u'heading', '/Page': IndirectObject(6, 0)}, ...]
    outlines = reader.outlines
    # List[Tuple[level(int), page(int), title(str)]]
    outlines = _parse_outline_tree(reader, outlines)
    max_length = max(len(item[-1]) + 2 * item[0] for item in outlines) + 1
    # print(outlines)
    with open(outline_txt_path, "w") as f:
        for level, page, title in outlines:
            level_space = "  " * level
            title_page_space = " " * (max_length - level * 2 - len(title))
            if is_python2:
                title = title.encode("utf-8")
            f.write("{}{}{}{}\n".format(level_space, title, title_page_space, page))
    return "The outline has been exported to %s" % outline_txt_path


if __name__ == "__main__":
    import sys

    args = sys.argv
    # print(extractOutline(args[1], args[2]))
    if len(args) != 3:
        print("Usage: %s [pdf] [output_txt]" % args[0])
    else:
        print(extractOutline(args[1], args[2]))
