for n in $(seq 0 15); do
  faketime +${n}days ./bin/debci --backend fake --concurrency 2
done
