function Badge({ type }) {
    let badgeContent;
    let badgeClass;

    switch (type) {
        case 'new':
            badgeContent = '✨ New';
            badgeClass = 'badge badge--info';
            break;
        case 'planned':
            badgeContent = '🚧 Planned';
            badgeClass = 'badge badge--warning';
            break;
        case 'deprecated':
            badgeContent = '🚫 Deprecated';
            badgeClass = 'badge badge--danger';
            break;
        default:
            badgeContent = '';
            badgeClass = '';
    }

    return (<span class={badgeClass}>{badgeContent}</span>);
}

export default Badge;