# Bunny

I like arch linux, but I don't like installing arch linux.
[Archinstall](https://github.com/archlinux/archinstall) allows you to automate the arch linux install process, but I'm too lazy for that.
So this project aims to help with automating the automated setup.

If your looking to install arch linux on alot of servers at once because of ̶ ̶m̶a̶s̶s̶ ̶s̶u̶r̶v̶e̶i̶l̶l̶a̶n̶c̶e̶,̶ ̶c̶e̶n̶s̶o̶r̶s̶h̶i̶p̶,̶ ̶a̶n̶d̶ ̶c̶a̶n̶c̶e̶l̶ ̶c̶u̶l̶t̶u̶r̶e̶  cool, new, rad technologies emerging that you want to test on bare metal servers or virtual machines, then this project might be for you.

Here is an overview of what is happening to slave nodes:

```ascii
+---------------------------------+
|   Generate Archinstall Config   |
+---------------------------------+
                |         
                |
                V         
      +--------------------+
      |   Boot Into Arch   |
      +--------------------+
                |         
                |
                V         
+--------------------------------+
|   Run Archinstall With Config  |
+--------------------------------+
                |         
                |
                V         
+----------------------------------------+
|   Run Additional Scripts From chroot   |
+----------------------------------------+
                |         
                |
                V
        +------------+
        |   Reboot   |
        +------------+
                |
                |
                V            
+---------------------------------+
|   Recieve Commands From Ansible |
+---------------------------------+
```