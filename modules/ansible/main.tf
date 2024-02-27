
resource "null_resource" "local" {
  provisioner "local-exec" {
    command = "cd ${path.module}; ansible-playbook -i '${var.ip},' --private-key ${var.ssh_private_key_path} instance.yml"
  }
}
