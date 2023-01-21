import chevron
import lxml.html
import prairielearn as pl

HEADER_DEFAULT = ""
TITLE_DEFAULT = ""
SUBTITLE_DEFAULT = ""
FOOTER_DEFAULT = ""
IMG_TOP_SRC_DEFAULT = ""
IMG_BOTTOM_SRC_DEFAULT = ""
WIDTH_DEFAULT = "auto"


def prepare(element_html: str, data: pl.QuestionData) -> None:
    element = lxml.html.fragment_fromstring(element_html)
    required_attribs = []
    optional_attribs = [
        "header",
        "title",
        "subtitle",
        "footer",
        "img-top-src",
        "img-bottom-src",
        "width",
    ]
    pl.check_attribs(element, required_attribs, optional_attribs)


def render(element_html: str, data: pl.QuestionData) -> str:
    element = lxml.html.fragment_fromstring(element_html)

    header = pl.get_string_attrib(element, "header", HEADER_DEFAULT)
    title = pl.get_string_attrib(element, "title", TITLE_DEFAULT)
    subtitle = pl.get_string_attrib(element, "subtitle", SUBTITLE_DEFAULT)
    footer = pl.get_string_attrib(element, "footer", FOOTER_DEFAULT)
    img_top_src = pl.get_string_attrib(element, "img-top-src", IMG_TOP_SRC_DEFAULT)
    img_bottom_src = pl.get_string_attrib(
        element, "img-bottom-src", IMG_BOTTOM_SRC_DEFAULT
    )
    width = pl.get_string_attrib(element, "width", WIDTH_DEFAULT)

    content = pl.inner_html(element)

    html_params = {
        "header": header,
        "title": lambda x, render: render(x, {"title": title}),
        "subtitle": subtitle,
        "footer": footer,
        "img-top-src": img_top_src,
        "img-bottom-src": img_bottom_src,
        "width": width.strip("%"),
        "content": content,
    }
    with open("pl-card.mustache", "r", encoding="utf-8") as f:
        html = chevron.render(f, html_params).strip()

    return html
