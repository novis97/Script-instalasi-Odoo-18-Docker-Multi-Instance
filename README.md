INSTRUKSI INSTALASI ODOO 18 DOCKER
# Download script instalasi
wget https://github.com/novis97/Script-instalasi-Odoo-18-Docker-Multi-Instance/blob/main/install_odoo18.sh
# Berikan permission execute
chmod +x install_odoo18.sh
# Jalankan script sebagai sudo
sudo ./install_odoo18.sh

Setelah Instalasi Selesai
# Logout dan login kembali agar user masuk grup docker
exit
su - <useranda>

# Masuk ke direktori Odoo
cd /home/<useranda>/odoo18

# Build dan jalankan containers
docker compose up -d --build

Verifikasi Instalasi
# Cek status containers
docker ps

# Cek logs jika ada masalah
docker compose logs -f odoo_sand1
docker compose logs -f postgres
docker compose logs -f nginx

# Cek status containers
docker ps

# Cek logs jika ada masalah
docker compose logs -f odoo_sand1
docker compose logs -f postgres
docker compose logs -f nginx

5. Akses Odoo Instances

    Instance 1: http://domain1.tld (Port 8069)
    Instance 2: http://domain2.tld (Port 8070)
    Instance 3: http://domain3.tld (Port 8071)

Akses langsung via IP:

    Instance 1: http://YOUR_SERVER_IP:8069
    Instance 2: http://YOUR_SERVER_IP:8070
    Instance 3: http://YOUR_SERVER_IP:8071

6. Setup Database Pertama Kali

    Buka browser ke salah satu instance
    Akan muncul form "Create Database"
    Isi:
        Database Name: sand1_db (atau sesuai instance)
        Email: admin@domain.tld
        Password: password_anda
        Language: Indonesian / English
        Country: Indonesia
        Klik "Create Database"

   7. Menambah Instance Baru
      # Masuk ke direktori odoo
      cd /home/<useranda>/odoo18

      # Buat direktori instance baru
      mkdir -p instances/domain4/{config,addons,filestore}

      # Copy konfigurasi dari instance lain
      cp instances/domain1/config/odoo.conf instances/domain4/config/

   Edit instances/domain4/config/odoo.conf:
   nano instances/domain4/config/odoo.conf
   # Ubah: dbfilter = ^sand4.*$
   # Ubah: logfile = /var/log/odoo/odoo-sand4.log

   Tambahkan ke docker-compose.yml:
     odoo_sand4:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: odoo18_sand4
    depends_on:
      - postgres
    environment:
      - HOST=postgres
      - USER=odoo
      - PASSWORD=odoo_password_2024
    volumes:
      - ./instances/sand4/config:/etc/odoo
      - ./instances/sand4/addons:/mnt/extra-addons
      - sand4_filestore:/var/lib/odoo/filestore
      - ./logs:/var/log/odoo
    ports:
      - "8072:8069"
    restart: unless-stopped
    networks:
      - odoo_network
  
   8. Menambah Extra Addons
      # Masuk ke direktori addons instance
cd /home/<useranda>/odoo18/instances/sand1/addons

# Clone addon dari GitHub
git clone https://github.com/OCA/server-tools.git

# Atau copy addon manual
cp -r /path/to/your/addon ./

# Restart container
docker compose restart odoo_domain1

9. Backup Database
    # Backup database
docker exec odoo18_postgres pg_dump -U odoo sand1_db > /home/salam/odoo18/backups/sand1_$(date +%Y%m%d_%H%M%S).sql

# Restore database
docker exec -i odoo18_postgres psql -U odoo -d sand1_db < /home/salam/odoo18/backups/sand1_backup.sql

10. Monitoring dan Maintenance
    # Lihat penggunaan resource
docker stats

# Restart semua services
docker compose restart

# Update Odoo (rebuild image)
docker compose down
docker compose up -d --build

# Cleanup unused images
docker system prune -f

11. Konfigurasi Domain (Opsional)
domain1.tld A YOUR_SERVER_IP
domain1.tld A YOUR_SERVER_IP  
domain1.tld A YOUR_SERVER_IP
