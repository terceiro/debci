#!/bin/sh
# remove all RabbitMQ queues to clean up after experiments
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl start_app
