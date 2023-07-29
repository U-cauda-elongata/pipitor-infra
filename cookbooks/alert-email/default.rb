node.validate! do
  {
    alert_email: {
      recipient: string,
    },
  }
end

template '/etc/systemd/system/alert-email@.service'
