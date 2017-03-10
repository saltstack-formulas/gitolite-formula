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

{{ user.username }}_user:
  user.present:
    - name: {{ user.username }}
    - shell: {{ shell }}
    - home: {{ home }}

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
    - user: {{ user.username }}
    - cwd: {{ home }}
    - creates: {{ home }}/bin/gitolite
    - require:
      - git: {{ home }}/gitolite
      - file: {{ home }}/bin

setup_gitolite_{{ user.username }}:
  cmd.run:
    - name: {{ home }}/gitolite/src/gitolite setup -pk {{ home }}/gitolite-admin.pub
    - user: {{ user.username }}
    - cwd: {{ home }}
    - env:
      - HOME: {{ home }}
    - onchanges:
      - file: {{ home }}/gitolite-admin.pub
    - require:
      - cmd: install_gitolite_{{ user.username }}
      - file: {{ home }}/gitolite-admin.pub
{% endfor %}
