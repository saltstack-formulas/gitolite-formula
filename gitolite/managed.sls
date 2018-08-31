{% from "gitolite/defaults.jinja" import gitolite with context %}
{% from "gitolite/defaults.jinja" import get_home %}
{% from "gitolite/defaults.jinja" import get_shell %}

include:
  - gitolite

{% for user in gitolite.users if user.get("managed", False) %}
{% set home = get_home(user, gitolite) %}
{% set shell = get_shell(user, gitolite) %}
{% set admin_home = "{}-admin".format(home) %}
{% set admin_username = "{}-admin".format(user.username) %}

{{ user.username }}_admin_user:
  user.present:
    - name: {{ admin_username }}
    - shell: {{ shell }}
    - home: {{ admin_home }}

{{ admin_home }}/.ssh:
  file.directory:
    - user: {{ admin_username }}
    - mode: 700
    - require:
      - user: {{ user.username }}_admin_user

generate_{{ user.username }}_admin_key:
  cmd.run:  
    - name: "ssh-keygen -t rsa -N '' -f {{ admin_home }}/.ssh/id_rsa"
    - runas: {{ admin_username }}
    - creates: {{ admin_home }}/.ssh/id_rsa.pub
    - require:
      - file: {{ admin_home }}/.ssh
      - user: {{ user.username }}_admin_user
    - require_in:
      - file: {{ home }}/gitolite-admin.pub

extend:
  {{ home }}/gitolite-admin.pub:
    file.copy:
      - force: True
      - source: {{ admin_home }}/.ssh/id_rsa.pub
      - onchanges:
        - cmd: generate_{{ user.username }}_admin_key

clone_admin_repo_{{ user.username }}:
  git.latest:
    - name: git@{{ gitolite.admin_host }}:gitolite-admin.git
    - rev: master
    - user: {{ admin_username }}
    - target: {{ admin_home }}/gitolite-admin
    - force_reset: True
    - require:
      - cmd: setup_gitolite_{{ user.username }}

set_name_admin_repo_{{ user.username }}:
  cmd.run:
    - name: "git config user.name 'Salt-generated gitolite-admin'"
    - unless: "git config user.name | grep -q '.*'"
    - runas: {{ admin_username }}
    - cwd: {{ admin_home }}/gitolite-admin
    - require:
      - git: clone_admin_repo_{{ user.username }}

set_email_admin_repo_{{ user.username }}:
  cmd.run:
    - name: "git config user.email '{{ user.username }}@{{ grains['id'] }}'"
    - unless: "git config user.email | grep -q '.*'"
    - runas: {{ admin_username }}
    - cwd: {{ admin_home }}/gitolite-admin
    - require:
      - git: clone_admin_repo_{{ user.username }}

{{ admin_home }}/gitolite-admin/conf/gitolite.conf:
  file.managed:
    - template: jinja
    - source: {{ user.get("gitolite_conf_source", "salt://gitolite/files/gitolite.conf.jinja") }}
    - user: {{ admin_username }}
    - group: {{ admin_username }}
    - require:
      - git: clone_admin_repo_{{ user.username }}

{% set ssh_pubkey_source = user.ssh_pubkey_source if "ssh_pubkey_source" in user else gitolite.ssh_pubkey_source %}
{% for key in user.get("ssh_pubkeys", []) %}
client_pubkey_{{key}}_admin_repo_{{ user.username }}:
  file.managed:
    - name: {{ admin_home }}/gitolite-admin/keydir/{{ key|replace("@", "_") }}.pub
    - user: {{ admin_username }}
    - group: {{ admin_username }}
    - source: {{ ssh_pubkey_source }}/{{ key }}.pub
    - require:
      - git: clone_admin_repo_{{ user.username }}
    - require_in:
      - cmd: commit_changes_admin_repo_{{ user.username }}
{% endfor%}

commit_changes_admin_repo_{{ user.username }}:
  cmd.run:
    - cwd: {{ admin_home }}/gitolite-admin
    - runas: {{ admin_username }}
    - name: "git add --all . && git commit -m 'Salt changed the config' && git push origin --all"
    - onlyif: "git status --porcelain | grep -q '.*'"
    - require:
      - git: clone_admin_repo_{{ user.username }}
      - cmd: set_name_admin_repo_{{ user.username }}
      - cmd: set_email_admin_repo_{{ user.username }}
{% endfor %}
