#!/bin/sh

parallel ./bin/debci worker --arch -- $(./bin/debci config --values-only arch_list)
