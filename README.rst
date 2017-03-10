========
gitolite
========

This formula sets up gitolite service.

.. note::

    See the full `Salt Formulas installation and usage instructions
    <http://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html>`_.

Formula Dependencies
====================

* git
* perl

Available states
================

.. contents::
    :local:

``gitolite``
------------

Installs the gitolite environment for the users specified in the pillar.

``gitolite.managed``
------------

Creates an admin user for each specified user and uses it to manage gitolite.
You may add your very own (Jinja-enabled) gitolite.conf and add loads of pubkeys.
