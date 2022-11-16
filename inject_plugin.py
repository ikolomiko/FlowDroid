#!/usr/bin/env python3
import sys
from lxml import etree, objectify

aar_plugin_xml = """
<plugin>
    <groupId>com.simpligility.maven.plugins</groupId>
    <artifactId>android-maven-plugin</artifactId>
    <version>4.6.0</version>
    <extensions>true</extensions>
    <configuration>
        <sign>
            <debug>false</debug>
        </sign>
    </configuration>
</plugin>
"""


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python3 inject_plugin.py <pom.xml path>")
        exit(1)

    path_pom = sys.argv[1]
    aar_plugin = etree.fromstring(aar_plugin_xml)
    tree = etree.parse(path_pom)
    root = tree.getroot()

    # Namespace sanitizer
    for elem in root.getiterator():
        if not hasattr(elem.tag, 'find'):
            continue
        i = elem.tag.find('}')
        if i >= 0:
            elem.tag = elem.tag[i+1:]
    objectify.deannotate(root, cleanup_namespaces=True)

    tag_project = root

    if tag_project is None:
        print("ERROR: Root tag 'project' not found!!!")
        exit(1)

    tag_build = tag_project.find("./build")
    if tag_build is None:
        tag_build = etree.SubElement(tag_project, 'build')

    tag_plugins = tag_build.find("./plugins")
    if tag_plugins is None:
        tag_plugins = etree.SubElement(tag_build, 'plugins')

    tag_plugins.append(aar_plugin)

    tree.write(path_pom)


if __name__ == '__main__':
    main()
