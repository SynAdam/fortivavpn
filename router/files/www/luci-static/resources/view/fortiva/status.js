'use strict';
'require view';
'require fs';
'require ui';
'require uci';
'require form';
'require poll';

// The Fortiva VPN page under Services: what the router's tunnel is doing,
// turning it on and off, a Premium code, and the settings in
// /etc/config/fortiva. Everything it shows comes from "fortiva status", the
// service's own answer, so the page and the command line always agree.

var STATES = {
	starting: _('Starting'),
	searching: _('Connecting'),
	connected: _('Connected'),
	paused: _('Turned off'),
	offline: _('Not connected. Trying again shortly.'),
	out_of_data: _('Today\'s data is used up')
};

function readStatus() {
	return L.resolveDefault(fs.exec_direct('/usr/bin/fortiva', [ 'status' ], 'json'), null);
}

function bytes(n) {
	if (n == null || isNaN(n))
		return '-';
	var units = [ 'B', 'KB', 'MB', 'GB', 'TB' ], i = 0;
	while (n >= 1024 && i < units.length - 1) {
		n /= 1024;
		i++;
	}
	return (i > 1 ? n.toFixed(1) : Math.round(n)) + ' ' + units[i];
}

function when(iso) {
	if (!iso)
		return '-';
	var d = new Date(iso);
	return isNaN(d) ? '-' : d.toLocaleString();
}

function row(label, value) {
	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'width': '33%' }, [ label ]),
		E('td', { 'class': 'td left' }, [ value ])
	]);
}

function statusRows(st) {
	if (!st)
		return [ row(_('Status'), _('The Fortiva service is not running.')) ];

	var rows = [ row(_('Status'), E('strong', {}, [ STATES[st.state] || st.state ])) ];
	if (st.state === 'connected' && st.door)
		rows.push(row(_('Server'), st.door.label || '-'));
	var q = st.quota;
	if (q) {
		if (q.unlimited) {
			rows.push(row(_('Data'), _('Unlimited (Premium)')));
		} else {
			rows.push(row(_('Data left today'), bytes(q.remaining_bytes) + ' / ' + bytes(q.limit_bytes)));
			if (q.resets_at)
				rows.push(row(_('Data resets'), when(q.resets_at)));
		}
	}
	if (st.network)
		rows.push(row(_('Internet connection'), st.network));
	if (st.device_id)
		rows.push(row(_('Router ID'), E('code', {}, [ st.device_id.substring(0, 8) ])));
	rows.push(row(_('Version'), st.version || '-'));
	return rows;
}

return view.extend({
	load: function() {
		return Promise.all([ readStatus(), uci.load('fortiva') ]);
	},

	toggle: function(on) {
		return fs.exec_direct('/usr/bin/fortiva', [ on ? 'connect' : 'disconnect' ])
			.then(L.bind(this.refresh, this))
			.catch(function(e) { ui.addNotification(null, E('p', {}, [ e.message ]), 'error'); });
	},

	redeem: function(input) {
		var code = (input.value || '').trim();
		if (!code)
			return Promise.resolve();
		return fs.exec_direct('/usr/bin/fortiva', [ 'redeem', code ], 'json').then(function(res) {
			if (res && res.ok) {
				input.value = '';
				ui.addNotification(null, E('p', {}, [ _('The code was applied to this router.') ]), 'info');
			} else {
				ui.addNotification(null, E('p', {}, [ _('The code was not accepted. Check it and try again.') ]), 'warning');
			}
		}).catch(function() {
			ui.addNotification(null, E('p', {}, [ _('The code could not be sent. Try again in a minute.') ]), 'error');
		}).then(L.bind(this.refresh, this));
	},

	refresh: function() {
		var self = this;
		return readStatus().then(function(st) { self.paint(st); });
	},

	paint: function(st) {
		var table = document.getElementById('fortiva-status');
		if (table) {
			while (table.firstChild)
				table.removeChild(table.firstChild);
			statusRows(st).forEach(function(r) { table.appendChild(r); });
		}
		var button = document.getElementById('fortiva-toggle');
		if (button) {
			var off = !st || st.state === 'paused';
			button.textContent = off ? _('Turn on') : _('Turn off');
			button.className = off ? 'btn cbi-button cbi-button-positive' : 'btn cbi-button cbi-button-negative';
			button.disabled = !st;
			button.dataset.on = off ? '1' : '0';
		}
	},

	render: function(data) {
		var self = this, st = data[0];

		var toggle = E('button', {
			'id': 'fortiva-toggle',
			'class': 'btn cbi-button',
			'click': ui.createHandlerFn(this, function(ev) {
				return self.toggle(ev.currentTarget.dataset.on === '1');
			})
		}, [ '' ]);

		var codeInput = E('input', {
			'type': 'text',
			'class': 'cbi-input-text',
			'placeholder': _('Premium code'),
			'autocomplete': 'off',
			'spellcheck': 'false'
		});
		var codeButton = E('button', {
			'class': 'btn cbi-button cbi-button-action',
			'click': ui.createHandlerFn(this, function() { return self.redeem(codeInput); })
		}, [ _('Apply code') ]);

		var status = E('div', { 'class': 'cbi-section' }, [
			E('h3', {}, [ _('Status') ]),
			E('table', { 'class': 'table', 'id': 'fortiva-status' }),
			E('div', { 'class': 'cbi-page-actions', 'style': 'text-align:left' }, [ toggle ]),
			E('h3', {}, [ _('Premium') ]),
			E('p', {}, [ _('A Premium code from Fortiva works on this router the same way it works on a phone.') ]),
			E('div', {}, [ codeInput, ' ', codeButton ])
		]);

		var m = new form.Map('fortiva', _('Fortiva VPN'),
			_('Every device on this network connects through Fortiva while it is on. Turn it off and the network uses its own connection.'));
		var s = m.section(form.NamedSection, 'main', 'fortiva', _('Settings'));
		s.addremove = false;

		var o = s.option(form.Flag, 'enabled', _('Start with the router'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Flag, 'dns_through_tunnel', _('Send lookups through Fortiva'),
			_('Devices on this network look up sites through Fortiva while it is connected.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'dns', _('Lookup servers'), _('IPv4 addresses, comma separated.'));
		o.placeholder = '1.1.1.1';
		o.datatype = 'string';
		o.validate = function(id, value) {
			if (!value)
				return true;
			var ok = value.split(',').every(function(a) {
				return /^\s*(\d{1,3}\.){3}\d{1,3}\s*$/.test(a);
			});
			return ok ? true : _('Enter IPv4 addresses separated by commas.');
		};

		o = s.option(form.Value, 'wan', _('Internet device'),
			_('Leave empty to use the device of the default route. Set it only when the router has more than one way out.'));
		o.optional = true;
		o.placeholder = _('automatic');

		return m.render().then(function(node) {
			// Under the page's title and description, above the settings.
			node.insertBefore(status, node.querySelector('.cbi-section'));
			self.paint(st);
			poll.add(L.bind(self.refresh, self), 5);
			return node;
		});
	}
});
