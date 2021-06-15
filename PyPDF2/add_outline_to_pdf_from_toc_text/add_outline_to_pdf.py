import io
import re
import sys

from distutils.version import LooseVersion
from os.path import exists, splitext
from PyPDF2 import PdfFileReader, PdfFileWriter


is_python2 = LooseVersion(sys.version) < '3'


def _get_parent_outline(current_indent, history_indent, outlines):
    '''The parent of A is the nearest outline whose indent is smaller than A's
    '''
    assert len(history_indent) == len(outlines)
    if current_indent == 0:
        return None
    for i in range(len(history_indent) - 1, -1, -1):
        # len(history_indent) - 1   ===>   0
        if history_indent[i] < current_indent:
            return outlines[i]
    return None

def addOutline(pdf_path, outline_txt_path, page_offset):
    if not exists(pdf_path):
        return "Error: No such file: {}".format(pdf_path)
    if not exists(outline_txt_path):
        return "Error: No such file: {}".format(outline_txt_path)

    with io.open(outline_txt_path, 'r', encoding='utf-8') as f:
        outline_lines = f.readlines()
    reader = PdfFileReader(pdf_path)
    writer = PdfFileWriter()
    writer.cloneDocumentFromReader(reader)

    maxPages = reader.getNumPages()
    outlines, history_indent = [], []
    # decide the level of each outline according to the relative indent size in each line
    #   no indent:          level 1
    #     small indent:     level 2
    #       larger indent:  level 3
    #   ...
    for line in outline_lines:
        line2 = re.split(r'\s+', line.strip())
        if len(line2) == 1:
            continue

        indent_size = len(line) - len(line.lstrip())
        parent = _get_parent_outline(indent_size, history_indent, outlines)
        history_indent.append(indent_size)

        title, page = ' '.join(line2[:-1]), int(line2[-1]) - 1
        if page + page_offset >= maxPages:
            return "Error: page index out of range: %d >= %d" % (page + page_offset, maxPages)
        new_outline = writer.addBookmark(title, page + page_offset, parent=parent)
        outlines.append(new_outline)

    out_path = splitext(pdf_path)[0] + '-new.pdf'
    with open(out_path,'wb') as f:
        writer.write(f)

    return "The outlines have been added to %s" % out_path


if __name__ == "__main__":
    import sys
    args = sys.argv
    if len(args) != 4:
        print("Usage: %s [pdf] [outline_txt] [page_offset]" % args[0])
    else:
        print(addOutline(args[1], args[2], int(args[3])))
