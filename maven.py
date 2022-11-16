#!/usr/bin/env python3

def main() -> None:
    data = []
    with open("repo_stats.csv", 'r') as file:
        data = [(item.strip().split(',')[0], item.strip().split(',')[2]) for item in file.readlines()]
    
    with open("newsettings-aar-jar.xml", "w") as file:
        for line in data:
            name=line[0].replace('&', '')
            url=line[1]
            url = url + '/' if url[-1] != '/' else url
            if "spring" in name.lower(): continue
            
            file.write(
f"""
    <repository>
        <id>{name}</id>
        <name>{name}</name>
        <url>{url}</url>
    </repository>
""")

if __name__ == '__main__':
    main()