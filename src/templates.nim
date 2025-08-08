import std/strutils

const
   HTML_DOCTYPE* = "<!DOCTYPE html>"
   HTML_OPEN* = """<html lang="en">"""
   HTML_CLOSE* = "</html>"
   HEAD_OPEN* = "<head>"
   HEAD_CLOSE* = "</head>"
   BODY_OPEN* = "<body>"
   BODY_CLOSE* = "</body>"

   META_CHARSET* = """<meta charset="UTF-8" />"""

   META_VIEWPORT* = """<meta name="viewport" content="width=device-width, initial-scale=1.0" />"""

   SIDEBAR_SOCIAL* = """
         <div class="sidebar-social">
            <a href="https://github.com/jonathanyale" class="social-link" target="_blank">github</a>
            <a href="https://www.youtube.com/@lambdaBoredom" class="social-link" target="_blank">youtube</a>
            <a href="mailto:jonathanyale@pm.me" class="social-link">email</a>
            <a href="feed.xml" class="social-link">feed</a>
         </div>"""

   BACK_LINK_POSTS* = """<a href="../../index.html" class="back-link">← Back to Posts</a>"""
   BACK_LINK_TAGS* = """<a href="../tag.html" class="back-link">← All Tags</a>"""

proc buildCssLink*(href: string): string =
   "<link rel=\"stylesheet\" href=\"" & href & "\" />"

proc buildHtmlTag*(tag: string, class: string = ""): tuple[open: string,
      close: string] =
   let classAttr = if class != "": " class=\"" & class & "\"" else: ""
   result.open = "<" & tag & classAttr & ">"
   result.close = "</" & tag & ">"

proc buildNavItem*(text: string, href: string, isActive: bool = false): string =
   let activeClass = if isActive: " active" else: ""
   result = """<li><a href="""" & href & """" class="nav-link""" &
         activeClass & """"><span class="nav-text">""" & text & """</span></a></li>"""

const
   CSS_RESET* = buildCssLink("./styles/reset.css")
   CSS_BASE* = buildCssLink("./styles/base.css")
   CSS_HOME* = buildCssLink("./styles/home.css")
   CSS_TAG* = buildCssLink("./styles/tag.css")

   CSS_RESET_BLOG* = buildCssLink("../../styles/reset.css")
   CSS_BASE_BLOG* = buildCssLink("../../styles/base.css")
   CSS_BLOG_BLOG* = buildCssLink("../../styles/blog.css")
   CSS_RESET_TAG* = buildCssLink("../styles/reset.css")
   CSS_BASE_TAG* = buildCssLink("../styles/base.css")
   CSS_HOME_TAG* = buildCssLink("../styles/home.css")
   CSS_TAG_TAG* = buildCssLink("../styles/tag.css")

const
   SIDEBAR = buildHtmlTag("aside", "sidebar")
   SIDEBAR_OPEN* = SIDEBAR.open
   SIDEBAR_CLOSE* = SIDEBAR.close

   SIDEBAR_NAV = buildHtmlTag("nav", "sidebar-nav")
   SIDEBAR_NAV_OPEN* = SIDEBAR_NAV.open & """<ul class="nav-list">"""
   SIDEBAR_NAV_CLOSE* = """</ul>""" & SIDEBAR_NAV.close

   MAIN_CONTENT = buildHtmlTag("div", "main-content")
   MAIN_CONTENT_OPEN* = MAIN_CONTENT.open
   MAIN_CONTENT_CLOSE* = MAIN_CONTENT.close

   CONTENT_MAIN = buildHtmlTag("main", "content-main")
   CONTENT_MAIN_OPEN* = CONTENT_MAIN.open
   CONTENT_MAIN_CLOSE* = CONTENT_MAIN.close

   BLOG_POST = buildHtmlTag("article", "blog-post")
   BLOG_POST_OPEN* = BLOG_POST.open
   BLOG_POST_CLOSE* = BLOG_POST.close

   BLOG_HEADER = buildHtmlTag("header", "blog-header")
   BLOG_HEADER_OPEN* = BLOG_HEADER.open
   BLOG_HEADER_CLOSE* = BLOG_HEADER.close

   BLOG_CONTENT = buildHtmlTag("main", "blog-content")
   BLOG_CONTENT_OPEN* = BLOG_CONTENT.open
   BLOG_CONTENT_CLOSE* = BLOG_CONTENT.close

   TAG_BACK = buildHtmlTag("div", "tag-back")
   TAG_BACK_OPEN* = TAG_BACK.open
   TAG_BACK_CLOSE* = TAG_BACK.close

   POSTS_HEADER = buildHtmlTag("header", "posts-header")
   POSTS_HEADER_OPEN* = POSTS_HEADER.open
   POSTS_HEADER_CLOSE* = POSTS_HEADER.close

   TAGS_CLOUD = buildHtmlTag("section", "tags-cloud")
   TAGS_CLOUD_OPEN* = TAGS_CLOUD.open
   TAGS_CLOUD_CLOSE* = TAGS_CLOUD.close

const
   NAV_HOME_ACTIVE* = buildNavItem("Home", "index.html", true)
   NAV_HOME_INACTIVE* = buildNavItem("Home", "index.html", false)
   NAV_HOME_INACTIVE_PARENT* = buildNavItem("Home", "../index.html", false)

   NAV_TAG_ACTIVE* = buildNavItem("Tags", "tag.html", true)
   NAV_TAG_INACTIVE* = buildNavItem("Tags", "tag.html", false)
   NAV_TAG_INACTIVE_PARENT* = buildNavItem("Tags", "../tag.html", false)
   NAV_TAG_ACTIVE_PARENT* = buildNavItem("Tags", "../tag.html", true)

proc buildTitle*(title: string): string =
   result = "<title>" & title & "</title>"

proc buildMetaField*(name: string, content: string): string =
   result = "<meta name='" & name & "' content='" & content & "' />"

proc buildBlogMetadata*(title: string, tags: string = "",
      date: string = ""): string =
   result = ""
   if title != "":
      result &= "<div class=\"blog-title\">" & title & "</div>"
   if tags != "" or date != "":
      result &= "<div class=\"blog-meta\">"
      if date != "":
         result &= "<span class=\"blog-date\">" & date & "</span>"
      if tags != "":
         let tagList = tags.split(",")
         result &= "<div class=\"blog-tags\">"
         for tag in tagList:
            let cleanTag = tag.strip()
            if cleanTag != "":
               result &= "<span class=\"tag\">" & cleanTag & "</span>"
         result &= "</div>"
      result &= "</div>"

proc buildPostsHeader*(title: string, count: int): string =
   result = POSTS_HEADER_OPEN &
            "<h1>" & title & "</h1>" &
            "<p>" & $count & " blogs in total</p>" &
            POSTS_HEADER_CLOSE

proc buildTagHeader*(tagName: string, count: int): string =
   result = POSTS_HEADER_OPEN &
            "<h1>" & tagName & "</h1>" &
            "<p>" & $count & " posts in this tag</p>" &
            POSTS_HEADER_CLOSE

proc buildBlogCard*(title: string, preview: string, url: string,
                    formattedDate: string, tagsHtml: string): string =
   result = "<article class=\"blog-card\">" &
            "<h3><a href=\"" & url & "\" class=\"card-title\">" & title &
                  "</a></h3>" &
            "<div class=\"card-preview\">" & preview & "</div>" &
            "<div class=\"card-meta\">" &
            "<span class=\"card-date\">" & formattedDate & "</span>" &
            "<div class=\"card-tags\">" & tagsHtml & "</div>" &
            "</div>" &
            "</article>"

proc buildTagLink*(tag: string, count: int): string =
   let countClass = if count >= 10: "tag-count-10-plus" else: "tag-count-" & $count
   result = "<span class=\"tag-item\">" &
           "<a href=\"tags/" & tag & ".html\" class=\"tag-link " &
                 countClass & "\">" &
           tag & "(" & $count & ")" &
           "</a>" &
           "</span>"

proc buildBlogPostTemplate*(metadata: string, header: string,
      document: string, footnotes: string = ""): string =
   result = HTML_DOCTYPE & HTML_OPEN & HEAD_OPEN & META_CHARSET &
         META_VIEWPORT & CSS_RESET_BLOG & CSS_BASE_BLOG & CSS_BLOG_BLOG &
         metadata & HEAD_CLOSE & BODY_OPEN  & "<div>" &
         BLOG_POST_OPEN & BLOG_HEADER_OPEN & BACK_LINK_POSTS &
         BLOG_HEADER_CLOSE & header & BLOG_CONTENT_OPEN & document &
         BLOG_CONTENT_CLOSE & footnotes & BLOG_POST_CLOSE & "</div>" &
               BODY_CLOSE & HTML_CLOSE

proc buildHtmlPage*(title: string, cssLinks: seq[string],
      bodyContent: string): string =
   var head = HEAD_OPEN & META_CHARSET & META_VIEWPORT & buildTitle(title)
   for css in cssLinks:
      head &= css
   head &= HEAD_CLOSE
   result = HTML_DOCTYPE & HTML_OPEN & head & BODY_OPEN & 
         bodyContent & BODY_CLOSE & HTML_CLOSE

proc buildSidebarWithNav*(homeActive: bool = false, tagActive: bool = false,
      useParentPaths: bool = false): string =
   let homeNav = if homeActive: NAV_HOME_ACTIVE
                 elif useParentPaths: NAV_HOME_INACTIVE_PARENT
                 else: NAV_HOME_INACTIVE
   let tagNav = if tagActive and useParentPaths: NAV_TAG_ACTIVE_PARENT
                    elif tagActive: NAV_TAG_ACTIVE
                    elif useParentPaths: NAV_TAG_INACTIVE_PARENT
                    else: NAV_TAG_INACTIVE
   result = SIDEBAR_OPEN & "<div><h2 class=\"profile-name\">λboredom</h2></div>" &
         SIDEBAR_SOCIAL & SIDEBAR_NAV_OPEN & homeNav & tagNav &
         SIDEBAR_NAV_CLOSE & SIDEBAR_CLOSE
