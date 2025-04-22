def check-local-ssh-agent [] {
     return (match $nu.os-info.name {
        "macos" => {
            # 1Password agent
            `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` | path exists
        }
        "windows" => {
            # Bundled OpenSSH agent and 1Password agent use the same socket
            `\\.\pipe\openssh-ssh-agent` | path exists
        }
        _ => false
    })
}

do --env {
    # If SSH_AUTH_SOCK is set, we assume the user has already started an SSH agent or forwarding is set up
    if ($env.SSH_AUTH_SOCK? | is-not-empty) {
        return
    }

    # Check if the user has a local SSH agent running
    if (check-local-ssh-agent) {
        return
    }

    # There is no SSH agent running, so we need to start one
    let ssh_agent_file = (
        $nu.temp-path | path join $"ssh-agent-($env.USER? | default $env.USERNAME).nuon"
    )

    if ($ssh_agent_file | path exists) {
        let ssh_agent_env = open ($ssh_agent_file)
        if ($"/proc/($ssh_agent_env.SSH_AGENT_PID)" | path exists) {
            load-env $ssh_agent_env
            return
        } else {
            rm $ssh_agent_file
        }
    }

    let ssh_agent_env = ^ssh-agent -c
        | lines
        | first 2
        | parse "setenv {name} {value};"
        | transpose --header-row
        | into record
    load-env $ssh_agent_env
    $ssh_agent_env | save --force $ssh_agent_file

    # Load the key
    if ($env.SSH_PRIVATE_KEY? | is-not-empty) {
       $env.SSH_PRIVATE_KEY | ^ssh-add -
    }
}
