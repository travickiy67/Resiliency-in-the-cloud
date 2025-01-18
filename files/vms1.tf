#считываем данные об образе ОС
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

# resource "yandex_compute_instance" "bastion"
resource "yandex_compute_instance" "vm1" {
  name        = "vm1" #Имя ВМ в облачной консоли
  hostname    = "vm1" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 50
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id #зона ВМ должна совпадать с зоной subnet!!!
    nat                = true
#    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.bastion.id]
  }
}


resource "yandex_compute_instance" "vm2" {
  name        = "vm2" #Имя ВМ в облачной консоли
  hostname    = "vm2" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!


  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = true }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id
    nat                = true
#    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]
  }
}

# resource "yandex_compute_instance" "web_b" {
#  name        = "web-b" #Имя ВМ в облачной консоли
#  hostname    = "web-b" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
#  platform_id = "standard-v3"
#  zone        = "ru-central1-b" #зона ВМ должна совпадать с зоной subnet!!!

#  resources {
#    cores         = var.test.cores
#    memory        = 1
#    core_fraction = 20
#  }

#  boot_disk {
#    initialize_params {
#      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
#      type     = "network-hdd"
#      size     = 10
#    }
#  }

#  metadata = {
#    user-data          = file("./cloud-init.yml")
#    serial-port-enable = 1
#  }

#  scheduling_policy { preemptible = true }

#  network_interface {
#    subnet_id          = yandex_vpc_subnet.develop_b.id
#    nat                = false
#    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]

#  }
#}

# resource "yandex_compute_instance" "wrong_b" {
#  name        = "wrong-hostname" #Имя ВМ в облачной консоли
#  platform_id = "standard-v3"
#  zone        = "ru-central1-b" #зона ВМ должна совпадать с зоной subnet!!!

#  resources {
#    cores         = var.test.cores
#    memory        = 1
#    core_fraction = 20
#  }

#  boot_disk {
#    initialize_params {
#      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
#      type     = "network-hdd"
#      size     = 10
#    }
#  }

#  metadata = {
#    user-data          = file("./cloud-init.yml")
#    serial-port-enable = 1
#  }

#  scheduling_policy { preemptible = true }

#  network_interface {
#    subnet_id          = yandex_vpc_subnet.develop_b.id
#    nat                = false
#    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]

#  }
#}


resource "local_file" "inventory" {
  content  = <<-XYZ
  [vm1]
  ${yandex_compute_instance.vm1.network_interface.0.nat_ip_address} 
  [vm2]
  ${yandex_compute_instance.vm2.network_interface.0.nat_ip_address} 

  # [webservers]
  # ${yandex_compute_instance.vm1.network_interface.0.ip_address}
  # ${yandex_compute_instance.vm2.network_interface.0.ip_address}
#  [webservers:vars]
#  ansible_ssh_common_args='-o ProxyCommand="ssh -p 22 -W %h:%p -q travitskii@${yandex_compute_instance.vm1.network_interface.0.nat_ip_address}"'
  XYZ
  filename = "./hosts.ini"
 }
resource "null_resource" "run_ansible_playbook" {
  #count = length(yandex_compute_instance.vm1)

 provisioner "local-exec" {
    command     = "until nc -zv ${yandex_compute_instance.vm1.network_interface.0.nat_ip_address} 22; do echo 'Waiting for SSH to be available...'; sleep 5; done"
    working_dir = path.module
  }

 provisioner "local-exec" {
    command     = "until nc -zv ${yandex_compute_instance.vm2.network_interface.0.nat_ip_address} 22; do echo 'Waiting for SSH to be available...'; sleep 5; done"
    working_dir = path.module
  }

 provisioner "local-exec" {
    command     = "ansible-playbook ./nginx_msql.yml"
    working_dir = path.module

  }

}


















