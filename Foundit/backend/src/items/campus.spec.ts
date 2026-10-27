import { campusForCoordinates, campusForLocation } from './campus';
import { ItemsService } from './items.service';
import { Item, ItemType, ItemStatus } from '../common/entities/item.entity';
import { User } from '../common/entities/user.entity';
describe('NCKU scope', () => {
  it('includes NCKU and leaves other Taiwan cities in the nationwide feed', () => {
    expect(campusForCoordinates(22.998, 120.22)).toBe('ncku');
    expect(campusForCoordinates(25.033, 121.565)).toBe('');
    expect(campusForCoordinates(22.63, 120.3)).toBe('');
    expect(campusForCoordinates(0, 0)).toBe('');
    expect(campusForCoordinates(null, null)).toBe('');
  });
  it.each(['成大', '成功大學', '國立成功大學', ' NCKU ', 'National Cheng Kung University'])('recognizes a campus-only legacy location %s', name => {
    expect(campusForLocation(null, null, name)).toBe('ncku');
  });
  it.each(['', '成大附近', '成大醫院旁', '成功大學附近', '清華大學'])('does not guess an ambiguous or nearby location %s', name => {
    expect(campusForLocation(null, null, name)).toBe('');
  });
  it('keeps coordinates authoritative even when the text names NCKU', () => {
    expect(campusForLocation(25.033, 121.565, '成大')).toBe('');
    expect(campusForLocation(22.998, 120.22, '圖書館')).toBe('ncku');
    expect(campusForLocation(null, 120.22, '成大')).toBe('');
  });
  it('classifies new App posts and reclassifies location-only edits without rewriting the listing identity', async () => {
    const id = '00000000-0000-4000-8000-000000000001';
    const owner = {id:'owner',status:'active'} as User;
    let item: Item;
    const repository = {
      create: (data: Partial<Item>) => ({...data, id}),
      save: async (data: Item) => (item = data),
      findOne: async () => item,
      update: jest.fn(async () => ({affected: 1})),
    };
    const service = new ItemsService(repository as never);
    item = await service.create({type:ItemType.LOST,title:'水壺',category:'其他',locationName:'成大',termsAccepted:true,termsVersion:'test'}, owner);
    expect(item.campusCode).toBe('ncku');
    expect(item.latitude).toBeNull();
    expect(item.status).toBe(ItemStatus.ACTIVE);
    await service.update(id, {locationName:'清華大學'}, owner);
    expect(item.campusCode).toBe('');
    await service.update(id, {locationName:'成大'}, owner);
    expect(item.campusCode).toBe('ncku');
    await service.update(id, {latitude:25.033,longitude:121.565}, owner);
    expect(item.campusCode).toBe('');
    expect(item.id).toBe(id);
    expect(item.userId).toBe(owner.id);
  });
});
