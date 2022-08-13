[Unit]

Description=my tested file
After=network.target

[Service]
Type=simple
ExecStart=/home/sargis/Desktop/test/script_rate.sh
Restart=on-failure
Restart=on-failuer
[Install]

WantedBy=multi-user.target

