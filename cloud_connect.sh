if [ "$1" = "sidekiq" ]; then
  echo "connecting to sidekiq..."
  ssh -i "SanctionSearch.pem" ubuntu@ec2-18-216-4-52.us-east-2.compute.amazonaws.com
elif [ "$1" = "sidekiq-2" ]; then
  echo "connecting to sidekiq-2..."
  ssh -i "SanctionSearch.pem" ubuntu@ec2-3-82-204-61.compute-1.amazonaws.com
else
  echo "connecting to web..."
  ssh -i "SanctionSearch.pem" ubuntu@ec2-18-220-29-50.us-east-2.compute.amazonaws.com
fi
