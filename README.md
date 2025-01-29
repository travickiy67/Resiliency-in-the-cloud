# Домашнее задание к занятию «Отказоустойчивость в облаке»
# Травицкий Сергей  
### Цель задания

В результате выполнения этого задания вы научитесь:  
1. Конфигурировать отказоустойчивый кластер в облаке с использованием различных функций отказоустойчивости. 
2. Устанавливать сервисы из конфигурации инфраструктуры.

------

### Чеклист готовности к домашнему заданию

1. Создан аккаунт на YandexCloud.  
2. Создан новый OAuth-токен.  
3. Установлено программное обеспечение  Terraform.   


### Инструкция по выполнению домашнего задания

1. Сделайте fork [репозитория c Шаблоном решения](https://github.com/netology-code/sys-pattern-homework) к себе в Github и переименуйте его по названию или номеру занятия, например, https://github.com/имя-вашего-репозитория/gitlab-hw или https://github.com/имя-вашего-репозитория/8-03-hw).
2. Выполните клонирование данного репозитория к себе на ПК с помощью команды `git clone`.
3. Выполните домашнее задание и заполните у себя локально этот файл README.md:
   - впишите вверху название занятия и вашу фамилию и имя
   - в каждом задании добавьте решение в требуемом виде (текст/код/скриншоты/ссылка)
   - для корректного добавления скриншотов воспользуйтесь инструкцией ["Как вставить скриншот в шаблон с решением"](https://github.com/netology-code/sys-pattern-homework/blob/main/screen-instruction.md)
   - при оформлении используйте возможности языка разметки md (коротко об этом можно посмотреть в [инструкции по MarkDown](https://github.com/netology-code/sys-pattern-homework/blob/main/md-instruction.md))
4. После завершения работы над домашним заданием сделайте коммит (`git commit -m "comment"`) и отправьте его на Github (`git push origin`);
5. Для проверки домашнего задания преподавателем в личном кабинете прикрепите и отправьте ссылку на решение в виде md-файла в вашем Github.
6. Любые вопросы по выполнению заданий спрашивайте в чате учебной группы и/или в разделе “Вопросы по заданию” в личном кабинете.


### Инструменты и дополнительные материалы, которые пригодятся для выполнения задания

1. [Документация сетевого балансировщика нагрузки](https://cloud.yandex.ru/docs/network-load-balancer/quickstart)

 ---

## Задание 1 

Возьмите за основу [решение к заданию 1 из занятия «Подъём инфраструктуры в Яндекс Облаке»](https://github.com/netology-code/sdvps-homeworks/blob/main/7-03.md#задание-1).

1. Теперь вместо одной виртуальной машины сделайте terraform playbook, который:

- создаст 2 идентичные виртуальные машины. Используйте аргумент [count](https://www.terraform.io/docs/language/meta-arguments/count.html) для создания таких ресурсов;
- создаст [таргет-группу](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/lb_target_group). Поместите в неё созданные на шаге 1 виртуальные машины;
- создаст [сетевой балансировщик нагрузки](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/lb_network_load_balancer), который слушает на порту 80, отправляет трафик на порт 80 виртуальных машин и http healthcheck на порт 80 виртуальных машин.

Рекомендуем изучить [документацию сетевого балансировщика нагрузки](https://cloud.yandex.ru/docs/network-load-balancer/quickstart) для того, чтобы было понятно, что вы сделали.

2. Установите на созданные виртуальные машины пакет Nginx любым удобным способом и запустите Nginx веб-сервер на порту 80.

3. Перейдите в веб-консоль Yandex Cloud и убедитесь, что: 

- созданный балансировщик находится в статусе Active,
- обе виртуальные машины в целевой группе находятся в состоянии healthy.

4. Сделайте запрос на 80 порт на внешний IP-адрес балансировщика и убедитесь, что вы получаете ответ в виде дефолтной страницы Nginx.

*В качестве результата пришлите:*

*1. Terraform Playbook.*

*2. Скриншот статуса балансировщика и целевой группы.*

*3. Скриншот страницы, которая открылась при запросе IP-адреса балансировщика.*

**Основной Файл vms.tf**
```
#считываем данные об образе ОС
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "vm" {
  count = 2 
  name        = "vm${count.index}" #Имя ВМ в облачной консоли
  hostname    = "vm${count.index}" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
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
  }
}
resource "yandex_lb_target_group" "group" {
  name = "group"
  target {
    subnet_id = yandex_vpc_subnet.develop_a.id
    address = yandex_compute_instance.vm[0].network_interface.0.ip_address
  }
  target { 
    subnet_id = yandex_vpc_subnet.develop_a.id
    address = yandex_compute_instance.vm[1].network_interface.0.ip_address
  }
}
resource "yandex_lb_network_load_balancer" "balancer1" {
  name = "balancer1"
  deletion_protection = "false"
  listener {
    name = "my-lb1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  
  attached_target_group {
    target_group_id = yandex_lb_target_group.group.id
    healthcheck {
      name = "http"
      http_options { 
        port = 80
        path = "/"
      }
    }
  }
}


resource "local_file" "inventory" {
  content  = <<-XYZ
  [vm0]
  ${yandex_compute_instance.vm[0].network_interface.0.nat_ip_address}
 
  [vm1]
  ${yandex_compute_instance.vm[1].network_interface.0.nat_ip_address}

  XYZ
  filename = "./hosts.ini"
 }
resource "null_resource" "run_ansible_playbook" {
  provisioner "local-exec" {
    command     = "until nc -zv ${yandex_compute_instance.vm[0].network_interface.0.nat_ip_address} 22; do echo 'Waiting for SSH to be available...'; sleep 5; done"
    working_dir = path.module
  }

 provisioner "local-exec" {
    command     = "until nc -zv ${yandex_compute_instance.vm[1].network_interface.0.nat_ip_address} 22; do echo 'Waiting for SSH to be available...'; sleep 5; done"
    working_dir = path.module
  }

 provisioner "local-exec" {
    command     = "ansible-playbook ./nginx_msql.yml"
    working_dir = path.module

  }

}
```
*Подсети и группа безопасности*  
[network](https://github.com/travickiy67/Resiliency-in-the-cloud/blob/main/files/network.tf)  

*Playbook использовался в домашнем задании для установки anginx и mysql, база закоментирована*  

[plybook](https://github.com/travickiy67/Resiliency-in-the-cloud/blob/main/files/nginx_msql.yml)  

*Статус балансировщика*  

![скриншот](https://github.com/travickiy67/Resiliency-in-the-cloud/blob/main/jmg/1.1.png)  

*при подключении через сайт с разных машин распредиляет запросы по очереди*  

![скриншот](https://github.com/travickiy67/Resiliency-in-the-cloud/blob/main/jmg/1.2.png)  

![скриншот](https://github.com/travickiy67/Resiliency-in-the-cloud/blob/main/jmg/1.3.png)   

*curl без параметров с одного хоста*  

![скриншот](https://github.com/travickiy67/Resiliency-in-the-cloud/blob/main/jmg/1.4.png)  
---

## Задания со звёздочкой*
Эти задания дополнительные. Выполнять их не обязательно. На зачёт это не повлияет. Вы можете их выполнить, если хотите глубже разобраться в материале.

---

## Задание 2*

1. Теперь вместо создания виртуальных машин создайте [группу виртуальных машин с балансировщиком нагрузки](https://cloud.yandex.ru/docs/compute/operations/instance-groups/create-with-balancer).

2. Nginx нужно будет поставить тоже автоматизированно. Для этого вам нужно будет подложить файл установки Nginx в user-data-ключ [метадаты](https://cloud.yandex.ru/docs/compute/concepts/vm-metadata) виртуальной машины.

- [Пример файла установки Nginx](https://github.com/nar3k/yc-public-tasks/blob/master/terraform/metadata.yaml).
- [Как подставлять файл в метадату виртуальной машины.](https://github.com/nar3k/yc-public-tasks/blob/a6c50a5e1d82f27e6d7f3897972adb872299f14a/terraform/main.tf#L38)

3. Перейдите в веб-консоль Yandex Cloud и убедитесь, что: 

- созданный балансировщик находится в статусе Active,
- обе виртуальные машины в целевой группе находятся в состоянии healthy.

4. Сделайте запрос на 80 порт на внешний IP-адрес балансировщика и убедитесь, что вы получаете ответ в виде дефолтной страницы Nginx.

*В качестве результата пришлите*

*1. Terraform Playbook.*

*2. Скриншот статуса балансировщика и целевой группы.*

*3. Скриншот страницы, которая открылась при запросе IP-адреса балансировщика.*

- Основной файл конфигурации vms.tf остальные не менялись те же что и в первом задании.
- nginx устанавливается автоматически, ip адреса вытащил с помощью скрипта script.sh из файла состояния
- Использовал depends_on, чтобы  null_resource создавался посленим.
- Создан time_sleep для ожидания загрузки vm.
 ```
 data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}


resource "yandex_compute_instance_group" "vm" {
  name                = "vm"
   service_account_id = "aje8v9g2qb161hgtbmmc"
   description = "my description"
  instance_template {
    platform_id = "standard-v3"
    resources {
      memory = 2
      cores  = 2
    }

    boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  scheduling_policy { preemptible = true }
    network_interface {
      network_id         = "${yandex_vpc_network.network-1.id}"
      subnet_ids         = ["${yandex_vpc_subnet.subnet-1.id}"]
      nat                = true

    }

    metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

 deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  load_balancer {
    target_group_name        = "target-group"
    target_group_description = "Целевая группа Network Load Balancer"
  }
}

resource "yandex_lb_network_load_balancer" "lb" {
  name = "network-load-balancer-1"

  listener {
    name = "network-load-balancer-1-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.vm.load_balancer.0.target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/index.html"
      }
    }
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"

}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.network-1.id}"
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "lb-ip" {
  value =yandex_lb_network_load_balancer.lb.listener
}

data "yandex_compute_instance_group" "vm" {
  instance_group_id = "${yandex_compute_instance_group.vm.id}"
}

output "instancegroupvm_external_ip" {
  value = "${data.yandex_compute_instance_group.vm.instances.*.network_interface.0.nat_ip_address}"

}
 resource "time_sleep" "wait_for_ingress_alb" {
create_duration = "50s"
  depends_on = [
    yandex_compute_instance_group.vm
    ]

}

resource "null_resource" "run_ansible_playbook" {
provisioner "local-exec" {
    command     = "./script.sh"
    working_dir = path.module

}


  provisioner "local-exec" {
    command     = "ansible-playbook ./nginx_msql.yml"
    working_dir = path.module

  }
   depends_on = [time_sleep.wait_for_ingress_alb]

}

```
*script.sh*
```
#! /bin/sh
#cat terraform.tfstate | grep nat_ip_address | tail -2 | cut -c 40-54 > hosts.ini
cat terraform.tfstate | grep nat_ip_address | cut -c 40-54 > hosts.ini
sed -i 's/[;,"&]//g'  ./hosts.ini
sort -u hosts.ini > host
mv -f host hosts.in
```
