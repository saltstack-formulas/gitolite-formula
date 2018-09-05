{% from "gitolite/defaults.jinja" import gitolite with context %}
{% from "gitolite/defaults.jinja" import get_home %}
{% from "gitolite/defaults.jinja" import get_shell %}

include:
  - git
  - perl

{% if grains['os'] == 'Amazon' %}
perl-Data-Dumper:
  pkg.installed
{% endif %}

{% for user in gitolite.users %}

{# variables #}
{% set shell = get_shell(user, gitolite) %}
{% set home = get_home(user, gitolite) %}
{% set ssh_pubkey = user.ssh_pubkey if user.ssh_pubkey is defined else gitolite.ssh_pubkey %}

{{ user.username }}_group:
  group.present:
    - name: {{ user.username }}
{% if user.get('group_add', [])|length > 0 %}
    - addusers:
{% for member in user.get('group_add', []) %}
      - {{ member }}
{% endfor %}
{% endif %}

{{ user.username }}_user:
  user.present:
    - name: {{ user.username }}
    - shell: {{ shell }}
    - home: {{ home }}
    - require:
      - group: {{ user.username }}_group

{{ home }}/.ssh:
  file.directory:
    - user: {{ user.username }}
    - mode: 700
    - require:
      - user: {{ user.username }}_user

{{ home }}/bin:
  file.directory:
    - user: {{ user.username }}
    - mode: 755
    - require:
      - user: {{ user.username }}_user

{{ home }}/gitolite:
  git.latest:
    - name: {{ gitolite.repository_url }}
    - rev: {{ gitolite.revision }}
    - user: {{ user.username }}
    - target: {{ home }}/gitolite
    - require:
      - user: {{ user.username }}_user

{{ home }}/gitolite-admin.pub:
  file.managed:
    - contents: {{ ssh_pubkey }}
    - user: {{ user.username }}

install_gitolite_{{ user.username }}:
  cmd.run:
    - name: {{ home }}/gitolite/install -ln {{ home }}/bin
    - runas: {{ user.username }}
    - cwd: {{ home }}
    - creates: {{ home }}/bin/gitolite
    - require:
      - git: {{ home }}/gitolite
      - file: {{ home }}/bin

{% if user.get('umask', False) %}
gitolite_set_umask_for_{{ user.username }}:
  file.replace:
    - name: {{ home }}/.gitolite.rc
    - pattern: "UMASK.*=>.*0.*,"
    - repl: "UMASK => {{ user.umask }},"
    - require:
      - cmd: install_gitolite_{{ user.username }}
    - require_in:
      - cmd: setup_gitolite_{{ user.username }}
{% endif %}

{% if user.get('git_config_keys', False) %}
gitolite_set_git_config_keys_for_{{ user.username }}:
  file.replace:
    - name: {{ home }}/.gitolite.rc
    - pattern: "GIT_CONFIG_KEYS.*=>.*,"
    - repl: "GIT_CONFIG_KEYS => '{{ user.git_config_keys }}',"
    - require:
      - cmd: install_gitolite_{{ user.username }}
    - require_in:
      - cmd: setup_gitolite_{{ user.username }}
{% endif %}

setup_gitolite_{{ user.username }}:
  cmd.run:
    - name: {{ home }}/gitolite/src/gitolite setup -pk {{ home }}/gitolite-admin.pub
    - runas: {{ user.username }}
    - cwd: {{ home }}
    - env:
      - HOME: {{ home }}
    - onchanges:
      - file: {{ home }}/gitolite-admin.pub
    - require:
      - cmd: install_gitolite_{{ user.username }}
      - file: {{ home }}/gitolite-admin.pub
{% endfor %}
