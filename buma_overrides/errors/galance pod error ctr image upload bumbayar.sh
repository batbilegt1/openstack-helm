Шийдэгдээгүй асуудлууд: 2025-11-06 16:08:38.588 7 INFO glance.api.v2.image_data [None req-bab6cf46-e290-422e-b76b-9cf89ccef1b8 ed199841be414168a87d9d29d57e4e42 745d8fbe95774cbb80da7a146853deed - - default default] Unable to create trust: no such option collect_timing in group [keystone_authtoken] Use the existing user token.
2025-11-06 16:08:38.642 7 ERROR glance.api.v2.image_data [None req-bab6cf46-e290-422e-b76b-9cf89ccef1b8 ed199841be414168a87d9d29d57e4e42 745d8fbe95774cbb80da7a146853deed - - default default] Failed to upload image data due to internal error: OSError: unable to receive chunked part
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi [None req-bab6cf46-e290-422e-b76b-9cf89ccef1b8 ed199841be414168a87d9d29d57e4e42 745d8fbe95774cbb80da7a146853deed - - default default] Caught error: unable to receive chunked part: OSError: unable to receive chunked part
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi Traceback (most recent call last):
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/common/wsgi.py", line 1165, in __call__
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     action_result = self.dispatch(self.controller, action,
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/common/wsgi.py", line 1208, in dispatch
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     return method(*args, **kwargs)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi            ^^^^^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/common/utils.py", line 411, in wrapped
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     return func(self, req, *args, **kwargs)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/api/v2/image_data.py", line 305, in upload
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     with excutils.save_and_reraise_exception():
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/oslo_utils/excutils.py", line 227, in __exit__
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     self.force_reraise()
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/oslo_utils/excutils.py", line 200, in force_reraise
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     raise self.value
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/api/v2/image_data.py", line 162, in upload
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     image.set_data(data, size, backend=backend)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/notifier.py", line 492, in set_data
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     with excutils.save_and_reraise_exception():
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/oslo_utils/excutils.py", line 227, in __exit__
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     self.force_reraise()
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/oslo_utils/excutils.py", line 200, in force_reraise
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     raise self.value
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/notifier.py", line 443, in set_data
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     self.repo.set_data(data, size, backend=backend,
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/quota/__init__.py", line 322, in set_data
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     self.image.set_data(data, size=size, backend=backend,
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/location.py", line 596, in set_data
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     self._upload_to_store(data, verifier, backend, size)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/location.py", line 487, in _upload_to_store
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     multihash, loc_meta) = self.store_api.add_with_multihash(
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance_store/multi_backend.py", line 425, in add_with_multihash
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     return store_add_to_backend_with_multihash(
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance_store/multi_backend.py", line 507, in store_add_to_backend_with_multihash
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     (location, size, checksum, multihash, metadata) = store.add(
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi                                                       ^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance_store/driver.py", line 294, in add_adapter
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     metadata_dict) = store_add_fun(*args, **kwargs)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance_store/capabilities.py", line 176, in op_checker
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     return store_op_fun(store, *args, **kwargs)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance_store/_drivers/filesystem.py", line 764, in add
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     raise errors.get(e.errno, e)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance_store/_drivers/filesystem.py", line 746, in add
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     for buf in utils.chunkreadable(image_file,
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance_store/common/utils.py", line 69, in chunkiter
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     chunk = fp.read(chunk_size)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi             ^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/common/utils.py", line 290, in read
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     result = self.data.read(i)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi              ^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/common/utils.py", line 117, in readfn
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     result = fd.read(*args)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi              ^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/oslo_utils/imageutils/format_inspector.py", line 1390, in read
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     chunk = self._source.read(size)
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi             ^^^^^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi   File "/var/lib/openstack/lib/python3.12/site-packages/glance/common/wsgi.py", line 908, in read
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi     data = uwsgi.chunked_read()
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi            ^^^^^^^^^^^^^^^^^^^^
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi OSError: unable to receive chunked part
2025-11-06 16:08:38.684 7 ERROR glance.common.wsgi 
[pid: 7|app: 0|req: 2757/2757] 10.244.39.12 () {34 vars in 747 bytes} [Thu Nov  6 16:08:38 2025] PUT /v2/images/968618d1-ed17-4a91-a8d5-e8f837347783/file => generated 228 bytes in 134 msecs (HTTP/1.1 500) 4 headers in 184 bytes (1 switches on 