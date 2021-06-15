A minimal example of extracting outlines from a PDF file
-----

### Prerequisite
1. pip install PyPDF2

### Steps
1. Copy [extract_pdf_outline.py](https://github.com/Emrys365/code_examples/blob/master/PyPDF2/extract_outline_from_pdf/extract_pdf_outline.py) to anywhere you like, say `${demo_dir}`
2. Prepare a PDF file with outlines, say `${pdf_path}`
3. Run the following command to export the outline in `${pdf_path}` to `${output_txt}`:
    ```bash
    python ${demo_dir}/extract_pdf_outline.py ${pdf_path} ${output_txt}
    ```

    <details><summary>Expand to see an example output</summary><div>

    ```bash
    $ python ./extract_pdf_outline.py ./demo.pdf ./toc.txt
    The outline has been exported to ./toc.txt

    $ head ./toc.txt
    Front Cover                1
    Title Page                 7
    Copyright                  8
    Table of Contents (Page 1) 25
    Section 1 (Page 1)         33
    Section 2 (Page 30)        62
    Section 3 (Page 66)        98
    Section 4 (Page 121)       165
    Section 5 (Page 143)       195
    Section 6 (Page 217)       269
    ```

    </div></details>
