# This is a Ruby file!

# =================================
# = Step 1: Setup SSH connections =
# =================================

# Synopsis: ssh_connection <name> <net-ssh options>
# For a list of options see:
#     http://net-ssh.github.io/net-ssh/Net/SSH.html#method-c-start
# The default options are { config: false }
ssh_connection :my_server, host_name: "example.com", user: "wheel", password: "secur3"

# Key authentication (if you don't specify any keys the default locations might be used)
ssh_connection :my_server, host_name: "example.com", user: "wheel", keys_only: true, keys: ["/home/itsme/.ssh/id_rsa"]

# Therefore you might get away with just
ssh_connection :my_server, host_name: "example.com", user: "wheel"

# There are also two shortcuts you can use...
ssh_connection :my_server, "wheel@example.com" # no additional options possible
ssh_connection :my_server, host: "wheel@example.com", port: 23 # additional options possible




# ==========================
# = Step 2: Monitor stuff! =
# ==========================


# -----
# SSL expiration
# -----
# Check if a SSL certificate is about to expire.
# Available options:
#
#    timeout    Maximum time to wait for request (default: 20 seconds)
#     verify    If enabled the peer will be verified (default: true)
#  threshold    Minimum certificate lifetime before showing warnings (default: 1.month)
#
ssl_expiration "https://example.com", threshold: 3.months


# -----
# WWW availability
# -----
# Check if a website is reachable and responses properly.
# Available options:
#
#    timeout    Maximum time to wait for request (default: 20 seconds)
#     status    HTTP status code or array of status codes
#       body    String (include check) or regular expression
#    headers    { header => value }
#                 * keys are lowercased!
#                 * value might be string (equal check) or regular expression
#
# Note: If page is https and ssl_expiration is not false
#       SSL expiration will automatically be checked.
#       You can pass options by setting ssl_expiration to a Hash.

www_availability "http://example.com", status: 200, body: "<title>Example.com</title>", headers: { "content-type" => "text/html; charset=utf-8" }

# SSL expiration
www_availability "https://example.com", ssl_expiration: false
www_availability "https://example.com", ssl_expiration: { threshold: 4.weeks }


# -----
# TCP port
# -----
# Attempts to establish a TCP connection to a given port.
# Host might be :local/SSH connection/String(IP/DNS)
# Available options:
#
#   message    Error message when connection cannot be established
#   timeout    Timeout in seconds to wait for a connection (default = 2 seconds - false/nil = 1 hour)
#
tcp_port "ftp.example.com", 21, message: "FTP offline"
tcp_port :my_server, 21, message: "FTP offline"


# -----
# UDP port
# -----
# Attempts to establish a UDP connection to a given port.
# NOTE: We send a message and attempt to receive a response.
#       If the port is closed we get an IO exception and assume the port to be unreachable.
#       If the port is open we most likely don't get ANY response and when the timeout
#       is reached we assume the port to be reachable. This is not an exact check.
# Host might be :local/SSH connection/String(IP/DNS)
# Available options:
#
#   message    Error message when connection cannot be established
#   timeout    Timeout in seconds to wait for a response (default = 2 seconds - false/nil = 1 hour)
#
udp_port "example.com", 9987, message: "Teamspeak offline"
udp_port :my_server, 9987, message: "Teamspeak offline"


# -----
# FTP availability
# -----
# Login to an FTP account via net/ftp to check it's functionality.
# Just a port check is not enough!
ftp_availability "ftp.example.com", user: "somebody", password: "thatiusedtoknow"


# -----
# TeamSpeak3 license expiration
# -----
# Checks ts3 license file for expiration. Default threshold is 1.month
ts3_license :my_server, "/path/to/licensekey.dat", threshold: 1.month


# -----
# MySQL replication
# -----
# Check the health of a MySQL replication.
# Host might be :local/false/nil which will test locally (without SSH)
# Available options: user(root), password, host(127.0.0.1), port(3306), sbm_threshold(60)
# SBM refers to "Seconds Behind Master"
mysql_replication :my_server, user: "replication_user", password: "pushit"


# -----
# *nix file_exist
# -----
# Check if a file exists or not.
# Host might be :local/false/nil which will test locally (without SSH)
# You can change the default message (The file ... does not exist) with the message option.
unix_file_exists :my_server, "/etc/passwd", message: "There is no passwd, spooky!"


# -----
# *nix df
# -----
# Checks if disks are running low on free space.
# Host might be :local/false/nil which will test locally (without SSH)
# Available options: min_percent(25)
unix_df :my_server
unix_df :my_server, min_percent: 50


# -----
# *nix memory
# -----
# Checks if memory is running low.
# Host might be :local/false/nil which will test locally (without SSH)
# Available options: min_percent(25)
unix_memory :my_server
unix_memory :my_server, min_percent: 50


# -----
# *nix load
# -----
# Checks if system load is to high.
# Host might be :local/false/nil which will test locally (without SSH)
# Available options: limits([4, 2, 1.5])
unix_load :my_server
unix_load :my_server, limits: [3, 2, 1]


# -----
# *nix mdadm
# -----
# Checks if mdadm raids are intact or checking.
# Host might be :local/false/nil which will test locally (without SSH)
# Available options: log_checking(true)
unix_mdadm :my_server
unix_mdadm :my_server, log_checking: false


# -----
# *nix defaults
# -----
# Combines unix_load, unix_memory, unix_df and unix_mdadm.
# You can pass options or disable individual checkers by passing
# a hash whose keys are named after checkers.
unix_defaults :my_server
unix_defaults :my_server, unix_mdadm: false, unix_df: { min_percent: 10 }

# There are also the following shortcuts:
unix_defaults :my_server, load: [1, 2, 3]  # Array(3) or false
unix_defaults :my_server, memory_min: 10   # Integer or false
unix_defaults :my_server, df_min: 10       # Integer or false
unix_defaults :my_server, mdadm: false     # true or false
