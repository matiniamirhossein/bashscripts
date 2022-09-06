import os
import shutil
import json
import subprocess

from sys import argv

# zip -r system-file-backup.zip /var/cpanel /etc/passwd /etc/group /etc/shadow /etc/domainusers /etc/dbowners /etc/localdomains /etc/userplans /etc/domainusers /etc/proftpd/passwd.vhosts /etc/userbwlimits /etc/trueuserowners /etc/userdomains /etc/userdatadomains /var/spool/cron/ /etc/proftpd

username = argv[1]

local_users = subprocess.check_output(["awk", "-F:", "$3>=1000 && $3!=65534 {print $1}", "/etc/passwd"]).strip().split("\n")

if username not in local_users:
    print("{} does not exist".format(username))
    exit(1)

hosts = subprocess.check_output(["mysql", "-u", "root", "-N", "-s", "-e", "select GROUP_CONCAT(distinct host) from mysql.user"]).strip()
hosts = hosts.split(",")
hosts.append("%")

def get_user_domains(username):
    domains = []
    
    try:
        lines = subprocess.check_output(["grep", ": {}$".format(username), "/etc/userdomains"]).strip().split("\n")
        for line in lines:
            line = line.strip()
            
            if line == "":
                continue

            domain = line.split(":")[0].strip()

            if domain == "":
                continue
            
            domains.append(domain)
    except:
        pass

    return domains

def check_user_existance(username):
    paths = {
        "/var/cpanel/users/" + username,
        "/var/cpanel/userdata/" + username,
        "/var/spool/cron/" + username,
    }

    for path in paths:
        if os.path.exists(path):
            return True

    files = {
        "/etc/passwd",
        "/etc/shadow",
        "/etc/domainusers",
        "/etc/userplans",
        "/etc/userips",
        "/etc/proftpd/passwd.vhosts",
        "/etc/userbwlimits",
        "/etc/trueuserowners",
        # "/etc/userdomains",
        # "/etc/userdatadomains",
        # "/etc/group",
    }

    for file in files:
        if not os.path.exists(file):
            continue

        with open(file) as f:
            if username + ":" in f.read():
                return True

    return False


def cleanup_user(username):
    if username == "":
        print("Username is empty")
        os.exit(1)

    domains = get_user_domains(username)

    for domain in domains:
        if os.path.exists("/var/named/{}.db".format(domain)):
            os.remove("/var/named/{}.db".format(domain))
        
        subprocess.call(["sed", "-i", "/^{}$/d".format(domain), "/etc/localdomains"])

    subprocess.call(["sed", "-i", "/^{}:/d".format(username), "/etc/userips"])
    subprocess.call(["sed", "-i", "/^{}:/d".format(username), "/etc/proftpd/passwd.vhosts"])
    subprocess.call(["sed", "-i", "/^{}:/d".format(username), "/etc/userplans"])
    subprocess.call(["sed", "-i", "/^{}:/d".format(username), "/etc/domainusers"])
    subprocess.call(["sed", "-i", "/^{}:/d".format(username), "/etc/trueuserowners"])
    subprocess.call(["sed", "-i", "/^{}:/d".format(username), "/etc/userbwlimits"])
    subprocess.call(["sed", "-i", "/: {}$/d".format(username), "/etc/userdomains"])
    subprocess.call(["sed", "-i", "/: {}==/d".format(username), "/etc/userdatadomains"])

    subprocess.call(["userdel", username])
    subprocess.call(["gpasswd", "--delete", username, "cpanelsuspended"])

    if os.path.exists("/var/cpanel/userdata/" + username):
        shutil.rmtree("/var/cpanel/userdata/" + username)

    if os.path.exists("/var/cpanel/bandwidth/{}.sqlite".format(username)):
        os.remove("/var/cpanel/bandwidth/{}.sqlite".format(username))

    if os.path.exists("/var/cpanel/users/" + username):
        os.remove("/var/cpanel/users/" + username)

    if os.path.exists("/var/spool/cron/" + username):
        os.remove("/var/spool/cron/" + username)

    if os.path.exists("/etc/proftpd/{}".format(username)):
        os.remove("/etc/proftpd/{}".format(username))

    if os.path.exists("/etc/proftpd/{}.suspended".format(username)):
        os.remove("/etc/proftpd/{}.suspended".format(username))

    if os.path.exists("/var/cpanel/databases/grants_{}.cache".format(username)):
        os.remove("/var/cpanel/databases/grants_{}.cache".format(username))

    if os.path.exists("/var/cpanel/databases/grants_{}.yaml".format(username)):
        os.remove("/var/cpanel/databases/grants_{}.yaml".format(username))

    for host in hosts:
        subprocess.call(["mysql", "-u", "root", "-e", "DROP USER '{}'@'{}'".format(username, host)])

    if os.path.exists("/var/cpanel/databases/{}.json".format(username)):
        with open("/var/cpanel/databases/{}.json".format(username)) as f:
            database_map = json.load(f)

            for database in database_map['MYSQL']['dbs']:
                subprocess.call(["mysql", "-u", "root", "-e", "DROP DATABASE {}".format(database)])
        
            for user in database_map['MYSQL']['dbusers']:
                for host in hosts:
                    subprocess.call(["mysql", "-u", "root", "-e", "DROP USER '{}'@'{}'".format(user, host)])

        os.remove("/var/cpanel/databases/{}.json".format(username))

    subprocess.call(["sed", "-i", "/^{}:/d".format(username), "/etc/dbowners"])

    subprocess.call(["/scripts/rebuilddnsconfig"])
    subprocess.call(["/scripts/rebuildhttpdconf"])

    try:
        if os.path.exists("/home/" + username):
            shutil.rmtree("/home/" + username)
    except:
        if os.path.exists("/home/" + username):
            os.unlink("/home/" + username)

    try:
        if os.path.exists("/home3/" + username):
            shutil.rmtree("/home3/" + username)
    except:
        pass

    try:
        if os.path.exists("/home2/" + username):
            shutil.rmtree("/home2/" + username)
    except:
        pass

    subprocess.call(["env", "PKGRESTORE=1", "/scripts/createacct", "remove-{}-remove.com".format(username), username, "oFH2TpgclJSq3Y"])
    subprocess.call(["/scripts/removeacct", username, "--force"])

if not check_user_existance(username):
    print("unable to find user in any of the paths")
    exit(1)

cleanup_user(username)
