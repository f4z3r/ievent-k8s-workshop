#!/usr/bin/env lua

--[[
Author: Jakob Beckmann <jakob.beckmann@ipt.ch>
Description:
  Cluster setup for iEvent workshop.
Dependencies:
 - Lua 5.3
External Dependencies:
 - kubectl
 - k3d
 - docker
]]--

local cluster_name = "ievent"
local registry_name = "ievent-reg"

local dashboard_link = "https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml"
local dashboard_sa = [[
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
]]

local dashboard_crb = [[
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
]]

function get_arg()
  if arg[1] == nil or arg[1] == "prep" or arg[1] == "token" then
    return arg[1]
  end
  io.write(string.format("ERROR: invalid argument: %s\n", arg[1]))
  os.exit(1)
end

function write_file(name, contents)
  local fh = io.open(name, "w")
  fh:write(contents)
  fh:close()
  return function() return os.execute("rm "..name) end
end

function run(cmd)
  local fh = io.popen(cmd)
  local out = fh:read("a")
  fh:close()
  return out
end

function run_lines(cmd)
  local fh = io.popen(cmd)
  return fh:lines()
end

function is_docker_running()
  local out = run("systemctl status snap.docker.dockerd.service")
  local match = out:match("Active: (%w+)")
  return match == "active"
end

function is_k3d_installed()
  return os.execute("k3d --version > /dev/null 2>&1")
end

function is_kubectl_installed()
  return os.execute("kubectl -h > /dev/null 2>&1")
end

function is_cluster_running(name)
  local out = run_lines("k3d cluster list")
  local found = false
  for line in out do
    if line:sub(0, #name) == name then
      found = true
      for current, total in line:gmatch("(%d)/(%d)") do
        if current ~= total then
          return false
        end
      end
    end
  end
  return found
end

function is_dashboard_deployed()
  return os.execute("kubectl get ns/kubernetes-dashboard > /dev/null 2>&1")
end

function setup_dashboard()
  local sa_file = os.tmpname()
  local crb_file = os.tmpname()
  local cmd = "kubectl apply -f %s"
  local worked = os.execute(string.format(cmd, dashboard_link))
  local del_sa = write_file(sa_file, dashboard_sa)
  worked = worked and os.execute(string.format(cmd, sa_file))
  worked = worked and del_sa()
  local del_crb = write_file(crb_file, dashboard_crb)
  worked = worked and os.execute(string.format(cmd, crb_file))
  worked = worked and del_crb()
  return worked
end

function create_cluster(name, registry)
  local cmd = "k3d registry create %s.localhost --port 5000"
  local worked = os.execute(string.format(cmd, registry))
  cmd = 'k3d cluster create %s -a 3 -s 1 -i rancher/k3s:v1.21.1-k3s1 --api-port 0.0.0.0:6550 -p "9080:80@loadbalancer" --registry-use k3d-%s.localhost:5000'
  worked = worked and os.execute(string.format(cmd, name, registry))
  worked = worked and os.execute("sleep 10s")
  return worked
end

function pre_checks()
  if not is_docker_running() then
    io.write("ERROR: docker does not seem to be running\n")
    os.exit(127)
  elseif not is_kubectl_installed() then
    io.write("ERROR: kubectl does not seem to be installed\n")
    os.exit(127)
  elseif not is_k3d_installed() then
    io.write("ERROR: k3d does not seem to be installed\n")
    os.exit(127)
  end

  if not is_cluster_running(cluster_name) then
    if not create_cluster(cluster_name, registry_name) then
      io.write("ERROR: failed to create cluster for setup\n")
      os.exit(127)
    end
  end

  if not is_dashboard_deployed() then
    if not setup_dashboard() then
      io.write("ERROR: failed to create cluster dashboard\n")
      os.exit(127)
    end
  end
end

function print_sa_token()
  local cmd = 'kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}"'
  local secret_name = run(cmd)
  cmd = 'kubectl -n kubernetes-dashboard get secret %s -o go-template="{{.data.token | base64decode}}"'
  local token = run(string.format(cmd, secret_name))
  io.write(token, "\n")
end

function main()
  pre_checks()
  if get_arg() == "token" then
    print_sa_token()
    return
  end
end

main()
